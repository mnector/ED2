param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [ValidateSet('auto','dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll')]
    [string]$ProxyName='auto'
)
$ErrorActionPreference='Stop'

$game=(Resolve-Path -LiteralPath $GameDir).Path
if (!(Test-Path -LiteralPath $game -PathType Container)) {throw 'Informe a pasta do executavel do jogo.'}
$running=Get-Process -ErrorAction SilentlyContinue | Where-Object {try {$_.Path -and ([IO.Path]::GetDirectoryName($_.Path) -eq $game)} catch {$false}}
if ($running) {throw 'Feche o jogo antes de instalar.'}

# 1. Download AMD-NR and DLSS-NR-on-AMD
Write-Host "Fetching latest releases from GitHub..."
$tempDir = Join-Path $env:TEMP "ED2_Payload"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

try {
    # 3zwr1/AMD-NR---OptiScaler latest release
    $releaseUrl = "https://api.github.com/repos/3zwr1/AMD-NR---OptiScaler/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl
    $amdnrAsset = $release.assets | Where-Object { $_.name -match "AMDNR-v.*\.zip" } | Select-Object -First 1
    $runtimeAsset = $release.assets | Where-Object { $_.name -match ".*-Runtime\.zip" } | Select-Object -First 1
    
    if (-not $amdnrAsset -or -not $runtimeAsset) { throw "Could not find release assets on GitHub." }
    
    Write-Host "Downloading $($amdnrAsset.name)..."
    Invoke-WebRequest -Uri $amdnrAsset.browser_download_url -OutFile "$tempDir\amdnr.zip"
    Write-Host "Downloading $($runtimeAsset.name)..."
    Invoke-WebRequest -Uri $runtimeAsset.browser_download_url -OutFile "$tempDir\runtime.zip"
} catch {
    throw "Failed to download required binaries: $_"
}

Write-Host "Extracting payloads..."
Expand-Archive -Path "$tempDir\amdnr.zip" -DestinationPath "$tempDir\amdnr" -Force
Expand-Archive -Path "$tempDir\runtime.zip" -DestinationPath "$tempDir\runtime" -Force

$isREEngine = (Get-ChildItem -LiteralPath $game -Filter 're_chunk_*.pak' -ErrorAction SilentlyContinue).Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $game 're9.exe'))
$isNMS = (Test-Path -LiteralPath (Join-Path $game 'NMS.exe'))
$proxies=@('dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll') | ForEach-Object {
    $candidate=Join-Path $game $_
    if(Test-Path -LiteralPath $candidate -PathType Leaf) {
        $name=[IO.Path]::GetFileName($candidate)
        $hash=(Get-FileHash -LiteralPath $candidate).Hash
        # AMD-NR proxy hashes can vary between versions, we just check if it's NOT system
        [pscustomobject]@{Name=$name;Path=$candidate;IsProxy=$true}
    }
}
if ($proxies.Count -gt 1) {throw "Multiplos proxies encontrados: $($proxies.Name -join ', '). Remova-os primeiro."}
if ($ProxyName -eq 'auto') {
    $proxyName=if($proxies){$proxies[0].Name}elseif($isNMS -or $isREEngine){'version.dll'}else{'dxgi.dll'}
}

$backup=Join-Path $game ('backup-amd-presr-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
$records=[System.Collections.Generic.List[psobject]]::new()

function Install-File([string]$source,[string]$relative) {
    if (-not (Test-Path $source)) { return }
    $dest=[IO.Path]::GetFullPath((Join-Path $game $relative))
    if (!$dest.StartsWith($game.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Destino fora da pasta do jogo.'}
    $existed=Test-Path -LiteralPath $dest -PathType Leaf
    if ($existed) {
        $saved=Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
        Copy-Item -LiteralPath $dest -Destination $saved
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $dest -Force
    $records.Add([pscustomobject]@{File=$relative;Existed=$existed;InstalledSHA256=(Get-FileHash -LiteralPath $dest).Hash})
}

Write-Host "Installing AMD-NR wrapper as $proxyName..."
Install-File (Join-Path "$tempDir\amdnr" 'OptiScaler.dll') $proxyName
foreach($name in @('OptiScaler.ini','dlssnr_amd_pass1.dll','dlssnr_amd_pass2.dll','dlssnr_amd_pass3.dll','dlssnr_on_amd_weights.bin','LmxxfNrRuntime.dll','LmxxfNrRuntime.pak')) {
    $src = if (Test-Path (Join-Path "$tempDir\amdnr" $name)) { Join-Path "$tempDir\amdnr" $name } else { Join-Path "$tempDir\runtime" $name }
    Install-File $src $name
}
$deps=Join-Path "$tempDir\amdnr" 'OptiScaler'
if (Test-Path $deps) {
    Get-ChildItem -LiteralPath $deps -File -Recurse | ForEach-Object {
        $relative=$_.FullName.Substring($deps.Length+1)
        Install-File $_.FullName (Join-Path 'OptiScaler' $relative)
    }
}
$records | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $backup 'manifest.json')

# Identify GPU
$rdnaGen = 3 # default
try {
    $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object {$_.Name -match 'AMD|Radeon'} | Select-Object -First 1
    if ($gpu) {
        Write-Host "Detected GPU: $($gpu.Name)"
        if ($gpu.Name -match '7\d{3}|Radeon.?.?7M') { $rdnaGen = 3 }
        elseif ($gpu.Name -match 'Radeon.*9\d{2}') { $rdnaGen = 4 }
        elseif ($gpu.Name -match '6\d{3}|Radeon.?.?6M') { $rdnaGen = 2 }
    }
} catch {}

function Set-IniValue($content, $section, $key, $val) {
    $pattern = "(?m)^\[$section\][\s\S]*?(?=(?:^\[)|`$)"
    if ($content -match $pattern) {
        $secContent = $matches[0]
        if ($secContent -match "(?m)^$key\s*=") {
            $secContent = $secContent -replace "(?m)^$key\s*=.*", "$key=$val"
        } else {
            $secContent = $secContent.TrimEnd() + "`r`n$key=$val`r`n"
        }
        $content = $content.Replace($matches[0], $secContent)
    }
    return $content
}

$iniDest = Join-Path $game 'OptiScaler.ini'
$iniContent = Get-Content $iniDest -Raw

$iniContent = Set-IniValue $iniContent 'FrameGen' 'SkipResizeBuffers' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'PreserveSwapChain' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifyBufferState' 'true'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifySCIndex'     'true'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'SkipReset'         'true'
$iniContent = Set-IniValue $iniContent 'Inputs'   'SkipReset'         'true'

if ($isUE) {
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'ColorResourceBarrier'        '4'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'MotionVectorResourceBarrier' '8'
}
if ($isREEngine) {
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'External' 'true'
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'Enabled'  'false'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedVendorId' '0x10de'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedDeviceId' '0x2204'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedGPUName'   'NVIDIA GeForce RTX 3090'
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'ScanExposure' 'false'
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'           'false'
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'RunBeforeSR'       'false'
    $iniContent = Set-IniValue $iniContent 'AmdLook' 'Enabled'          'true'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'RestoreComputeSignature' 'false'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'RestoreGraphicSignature' 'false'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'DisableOverlays' 'true'
    $iniContent = Set-IniValue $iniContent 'Menu' 'OverlayMenu' 'true'
    $iniContent = Set-IniValue $iniContent 'Menu' 'ShortcutKey' '0x24'
    $iniContent = Set-IniValue $iniContent 'Menu' 'MenuKey'     '0x24'
}
if ($isNMS) {
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'Vulkan'                  'true'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'VulkanExtensionSpoofing' 'false'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedVendorId'         '0x10de'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedDeviceId'         '0x2204'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedGPUName'          'NVIDIA GeForce RTX 3090'
    $iniContent = Set-IniValue $iniContent 'Upscalers' 'VulkanUpscaler'         'ffx'
}
$isGTA = (Test-Path -LiteralPath (Join-Path $game 'GTA5.exe')) -or (Test-Path -LiteralPath (Join-Path $game 'GTA5_Enhanced.exe')) -or (Test-Path -LiteralPath (Join-Path $game 'PlayGTAV.exe'))
if ($isGTA) {
    $iniContent = Set-IniValue $iniContent 'Menu' 'ShortcutKey' '0x2D'
    $iniContent = Set-IniValue $iniContent 'Menu' 'MenuKey'     '0x2D'
}
$iniContent = Set-IniValue $iniContent 'Framerate' 'FramerateLimit' '0.0'

# Configure AMD-NR Model Interleave for Real-Time performance
$iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdInterleave' '0'
$iniContent = Set-IniValue $iniContent 'Spoofing' 'Dxgi' 'true'
$iniContent | Set-Content $iniDest
Write-Host "OptiScaler.ini tuned for RDNA $rdnaGen."

Write-Host "Instalado em: $game"
Write-Host "Proxy: $proxyName"
Write-Host "Backup em: $backup"

# Clean up temp
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'AMD-NR runtime configured successfully from remote sources.'

