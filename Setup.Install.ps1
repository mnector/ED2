param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [ValidateSet('auto','dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll')]
    [string]$ProxyName='auto'
)
$ErrorActionPreference='Stop'
# Check the complete backend before changing any game files. These binaries
# expose a private ABI and cannot be mixed with another OptiScaler AMD release.
$runtimeHash='3C9CA13F0F5FC36A690BA424C457003BCFCC1080B4B785974CDD7E9AE2BC1DD8'
foreach ($pass in 1..3) {
    $runtime=Join-Path $PSScriptRoot "dlssnr_amd_pass$pass.dll"
    if (!(Test-Path -LiteralPath $runtime -PathType Leaf) -or (Get-FileHash -LiteralPath $runtime).Hash -ne $runtimeHash) {
        throw "Missing or incompatible AMD pass $pass. Extract the complete release package before running Setup."
    }
}
foreach ($required in @('OptiScaler.dll','OptiScaler.ini','dlssnr_on_amd_weights.bin','OptiScaler')) {
    if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $required))) {throw "Incomplete package: $required is missing."}
}
foreach ($required in @('GatherCS.cso','ResolveCS.cso')) {
    if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot ('experimental_lighting/'+$required)) -PathType Leaf)) {throw "Incomplete RTGI package: $required is missing."}
}
$game=(Resolve-Path -LiteralPath $GameDir).Path
if (!(Test-Path -LiteralPath $game -PathType Container)) {throw 'Informe a pasta do executavel do jogo.'}
$running=Get-Process -ErrorAction SilentlyContinue | Where-Object {try {$_.Path -and ([IO.Path]::GetDirectoryName($_.Path) -eq $game)} catch {$false}}
if ($running) {throw 'Feche o jogo antes de instalar.'}
$isREEngine = (Get-ChildItem -LiteralPath $game -Filter 're_chunk_*.pak' -ErrorAction SilentlyContinue).Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $game 're9.exe'))
$isNMS = (Test-Path -LiteralPath (Join-Path $game 'NMS.exe'))
$proxies=@('dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll') | ForEach-Object {
    $candidate=Join-Path $game $_
    if(Test-Path -LiteralPath $candidate -PathType Leaf) {
        $item=Get-Item -LiteralPath $candidate
        if($item.VersionInfo.ProductName -eq 'OptiScaler' -or $item.VersionInfo.FileDescription -eq 'OptiScaler') {$item.Name}
    }
}
if(@($proxies).Count -gt 1){throw ('Mais de um proxy OptiScaler encontrado: '+($proxies -join ', ')+'. Mantenha apenas o proxy que deseja usar antes de atualizar.')}
$proxyName=if($ProxyName -eq 'auto') {
    if(@($proxies).Count -eq 1){@($proxies)[0]}else{
        if ($isREEngine) { 'version.dll' }
        elseif ($isNMS) { 'dbghelp.dll' }
        else { 'dxgi.dll' }
    }
} else {$ProxyName.ToLowerInvariant()}
if(@($proxies).Count -eq 1 -and $ProxyName -ne 'auto' -and @($proxies)[0] -ne $proxyName) {
    throw ('OptiScaler is already installed as '+@($proxies)[0]+'. Move it before selecting '+$proxyName+'.')
}
$backup=Join-Path $game ('backup-amd-presr-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
$records=[Collections.Generic.List[object]]::new()
function Install-File([string]$source,[string]$relative) {
    $dest=[IO.Path]::GetFullPath((Join-Path $game $relative))
    if (!$dest.StartsWith($game.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Destino fora da pasta do jogo.'}
    $existed=Test-Path -LiteralPath $dest
    if ($existed) {
        $saved=Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
        Copy-Item -LiteralPath $dest -Destination $saved
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $dest -Force
    $records.Add([pscustomobject]@{File=$relative;Existed=$existed;InstalledSHA256=(Get-FileHash -LiteralPath $dest).Hash})
}
# The original AMD proxy would otherwise evaluate NR a second time after FSR.
$standalone=Join-Path $game 'version.dll'
if((Test-Path -LiteralPath $standalone) -and $proxyName -ne 'version.dll') {
    $sha=(Get-FileHash -LiteralPath $standalone).Hash
    if($sha -ne '106223723FD9266C44D38DC2FB77933948AB37803F46BFCEA2BAE3A0A474AC84') {
        throw 'Existe uma version.dll diferente da original analisada. Identifique-a antes de instalar para evitar conflito de proxies.'
    }
    Move-Item -LiteralPath $standalone -Destination (Join-Path $backup 'version.dll')
}
# Clean up any rogue nvngx.dll that is actually an OptiScaler copy (unsupported DLL name that breaks Streamline NGX context)
$rogueNvngx = Join-Path $game 'nvngx.dll'
if (Test-Path -LiteralPath $rogueNvngx) {
    $item = Get-Item -LiteralPath $rogueNvngx
    if ($item.VersionInfo.ProductName -eq 'OptiScaler' -or $item.VersionInfo.FileDescription -eq 'OptiScaler' -or (Get-FileHash -LiteralPath $rogueNvngx).Hash -eq (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'OptiScaler.dll')).Hash) {
        Move-Item -LiteralPath $rogueNvngx -Destination (Join-Path $backup 'nvngx.dll') -Force
    }
}
Install-File (Join-Path $PSScriptRoot 'OptiScaler.dll') $proxyName
foreach($name in @('OptiScaler.ini','dlssnr_amd_pass1.dll','dlssnr_amd_pass2.dll','dlssnr_amd_pass3.dll','dlssnr_on_amd_weights.bin')) {
    Install-File (Join-Path $PSScriptRoot $name) $name
}
$deps=Join-Path $PSScriptRoot 'OptiScaler'
Get-ChildItem -LiteralPath $deps -Recurse -File | ForEach-Object {
    $relative='OptiScaler\'+$_.FullName.Substring($deps.Length).TrimStart('\')
    Install-File $_.FullName $relative
}
$rtgi=Join-Path $PSScriptRoot 'experimental_lighting'
Get-ChildItem -LiteralPath $rtgi -File | ForEach-Object {
    Install-File $_.FullName ('experimental_lighting\'+$_.Name)
}
$records | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $backup 'manifest.json')


# ── GPU Detection & DlssNr Auto-Tune ────────────────────────────────────────
# Detect the discrete AMD GPU and its RDNA generation to set optimal neural
# rendering parameters.  RDNA 2 lacks the compute throughput for NR without
# constant timeouts; RDNA 3 can handle light NR; RDNA 4 gets full support.
$gpuInfo = Get-CimInstance Win32_VideoController |
    Where-Object { $_.Name -match 'Radeon' -and $_.Name -notmatch '^AMD Radeon\(TM\) Graphics$' } |
    Select-Object -First 1

$rdnaGen = 0
if ($gpuInfo) {
    $pnp = $gpuInfo.PNPDeviceID
    if ($pnp -match 'DEV_([0-9A-Fa-f]{4})') {
        $devId = [Convert]::ToInt32($Matches[1], 16)
        # RDNA 4: Navi 48/44 (0x7540-0x755F)
        if ($devId -ge 0x7540 -and $devId -le 0x755F) { $rdnaGen = 4 }
        # RDNA 3: Navi 31/32/33 (0x7440-0x745F, 0x7480-0x749F)
        elseif (($devId -ge 0x7440 -and $devId -le 0x745F) -or
                ($devId -ge 0x7480 -and $devId -le 0x749F)) { $rdnaGen = 3 }
        # RDNA 2: Navi 21/22/23/24 (0x73A0-0x73FF)
        elseif ($devId -ge 0x73A0 -and $devId -le 0x73FF) { $rdnaGen = 2 }
    }
}
Write-Host "Detected GPU: $($gpuInfo.Name) (RDNA $rdnaGen)"

# Read the installed INI and patch DlssNr + FSRFG sections in-place.
$iniDest = Join-Path $game 'OptiScaler.ini'
$iniContent = Get-Content $iniDest

# Helper: set or update a key=value line under a given [Section].
function Set-IniValue([string[]]$lines, [string]$section, [string]$key, [string]$value) {
    $inSection = $false
    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\[') {
            $inSection = ($lines[$i].Trim() -eq "[$section]")
            if ($inSection) { $sectionIndex = $i }
        }
        if ($inSection -and $lines[$i] -match "^$key=") {
            $lines[$i] = "$key=$value"
            return $lines
        }
    }
    if ($sectionIndex -ge 0) {
        $newLines = [Collections.Generic.List[string]]::new($lines)
        $newLines.Insert($sectionIndex + 1, "$key=$value")
        return $newLines.ToArray()
    }
    return $lines
}

# ── DlssNr parameters based on RDNA generation ──
switch ($rdnaGen) {
    4 {
        # RDNA 4: Full neural rendering support
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'RunBeforeSR'                'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'ScanExposure'               'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdModelScale'              '1'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLighting'          'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLightingStrength'  '0.5'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Passes'                     '1'
    }
    3 {
        # RDNA 3: Light NR, reduced neural lighting to avoid timeouts
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'RunBeforeSR'                'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'ScanExposure'               'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdModelScale'              '1'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLighting'          'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLightingStrength'  '0.3'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Passes'                     '1'
    }
    default {
        # RDNA 2 or unknown: Disable NR entirely to prevent timeout storms
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'RunBeforeSR'                'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'ScanExposure'               'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdModelScale'              '0'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLighting'          'false'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLightingStrength'  '0'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Passes'                     '1'
    }
}

# ── FSRFG Frame Pace Tuning: conservative margins ──
$iniContent = Set-IniValue $iniContent 'FSRFG' 'FPTSafetyMarginInMs' '0.75'
$iniContent = Set-IniValue $iniContent 'FSRFG' 'FPTVarianceFactor'   '0.3'
$iniContent = Set-IniValue $iniContent 'FSRFG' 'FPTHybridSpin'       'true'

# ── Swapchain Stability: Prevent crashes on resolution/menu changes ──
$iniContent = Set-IniValue $iniContent 'FrameGen' 'SkipResizeBuffers' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'PreserveSwapChain' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifyBufferState' 'true'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifySCIndex'     'true'

# ── Resource Barriers: only for UE5 AMD (breaks RE Engine / other D3D12 engines) ──
$isUE = ($game -match 'Binaries[\\/]Win64') -or (Test-Path -LiteralPath (Join-Path $game '..\..\Engine') -PathType Container)
if ($isUE) {
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'ColorResourceBarrier'        '4'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'MotionVectorResourceBarrier' '8'
}

# ── RE Engine tuning: enable DLSS pipeline, isolate FG, disable signature traps & overlays ──
if ($isREEngine) {
    # Isolate FrameGen so OptiScaler does not hook swapchain with uninitialized FG
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'External' 'true'
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'Enabled'  'false'
    # Spoof RTX 3090: unlocks DLSS SR and DLSS Ray Reconstruction in game menu without triggering Streamline DLSS-G (Ada exclusive) crashes
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedVendorId' '0x10de'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedDeviceId' '0x2204'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedGPUName'   'NVIDIA GeForce RTX 3090'
    # Disable exposure scanner (RE Engine's 64+ buffer allocations cause scan table overflow/crashes)
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'ScanExposure' 'false'
    # Use post-SR AmdLook conversion; disable heavy neural compute pass to prevent driver timeouts on RDNA4
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'           'false'
    $iniContent = Set-IniValue $iniContent 'DlssNr' 'RunBeforeSR'       'false'
    $iniContent = Set-IniValue $iniContent 'AmdLook' 'Enabled'          'true'
    # Monolithic REFramework handles root signatures; forcing OptiScaler to restore them causes 0x887a0006 device hung crashes on Present
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'RestoreComputeSignature' 'false'
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'RestoreGraphicSignature' 'false'
    # Disable Steam/Epic Overlays: Overlay hooks severely conflict with RE Engine's DXGI integration and FrameGen wrappers
    $iniContent = Set-IniValue $iniContent 'Hotfix' 'DisableOverlays' 'true'
    # Overlay menu on VK_HOME (0x24) to avoid collision with REFramework's Insert key
    $iniContent = Set-IniValue $iniContent 'Menu' 'OverlayMenu' 'true'
    $iniContent = Set-IniValue $iniContent 'Menu' 'ShortcutKey' '0x24'
    $iniContent = Set-IniValue $iniContent 'Menu' 'MenuKey'     '0x24'
}

# ── No Man's Sky (Vulkan) tuning: enable Vulkan spoofing so DLSS is exposed on AMD ──
if ($isNMS) {
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'Vulkan'                  'true'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'VulkanExtensionSpoofing' 'false'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedVendorId'         '0x10de'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedDeviceId'         '0x2204'
    $iniContent = Set-IniValue $iniContent 'Spoofing' 'SpoofedGPUName'          'NVIDIA GeForce RTX 3090'
    $iniContent = Set-IniValue $iniContent 'Upscalers' 'VulkanUpscaler'         'ffx'
}

# ── Framerate: remove the daemon's static limit ──
$iniContent = Set-IniValue $iniContent 'Framerate' 'FramerateLimit' '0.0'

$iniContent | Set-Content $iniDest
Write-Host "OptiScaler.ini tuned for RDNA $rdnaGen."

Write-Host "Instalado em: $game"
Write-Host "Proxy: $proxyName"
Write-Host "Backup em: $backup"

Write-Host 'Reinicie o computador se for a primeira vez que executa o Envy-Diamond.'


# ── Dynamic Pacing ASI Plugin ───────────────────────────────────────────────
$pluginsDir = Join-Path $game 'OptiScaler\plugins'
if (-not (Test-Path $pluginsDir)) { New-Item -ItemType Directory -Path $pluginsDir | Out-Null }
# Install as -loadlate so it injects 30 seconds later, ensuring dlssnr_amd_pass DLLs are in memory to be patched!
Install-File (Join-Path $PSScriptRoot 'EnvyDynamicPacing.asi') (Join-Path 'OptiScaler\plugins' 'EnvyDynamicPacing-loadlate.asi')

# Ensure Plugins are enabled in INI
$iniContent = Set-IniValue $iniContent 'Plugins' 'LoadAsiPlugins' 'true'
$iniContent | Set-Content $iniDest

# ── TDR Registry Configuration & Backup ────────────────────────────────────
$tdrBackupPath = Join-Path $backup 'tdr_backup.json'
$tdrKeys = @('TdrDelay', 'TdrDdiDelay', 'TdrLimitCount', 'TdrLimitTime')
$tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'

# Check current TDR values and create backup
$tdrBackup = @{}
$currentTdrValid = $true

foreach ($key in $tdrKeys) {
    try {
        $value = Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction Stop | Select-Object -ExpandProperty $key
        $tdrBackup[$key] = $value
    } catch {
        $tdrBackup[$key] = $null
        $currentTdrValid = $false
    }
}

# Save backup to JSON
$tdrBackup | ConvertTo-Json | Set-Content $tdrBackupPath
Write-Host "TDR settings backed up to: $tdrBackupPath"

# Check if TDR values are adequate for DLSS-NR
$tdrDelay = $tdrBackup['TdrDelay']
$tdrDdiDelay = $tdrBackup['TdrDdiDelay']
$tdrLimitCount = $tdrBackup['TdrLimitCount']
$tdrLimitTime = $tdrBackup['TdrLimitTime']

Write-Host ""
Write-Host "Current TDR Settings:"
Write-Host "  TdrDelay (default 2s):      ${tdrDelay}s"
Write-Host "  TdrDdiDelay (default 5s):   ${tdrDdiDelay}s"
Write-Host "  TdrLimitCount (default 5):  ${tdrLimitCount}"
Write-Host "  TdrLimitTime (default 60s): ${tdrLimitTime}s"
Write-Host ""

# Recommend TDR changes if values are too low
$needsTdrUpdate = $false
$tdrRecommendation = ""

if ($tdrDelay -lt 60 -or $tdrDelay -eq 0) {
    $needsTdrUpdate = $true
    $tdrRecommendation += "  - TdrDelay should be >= 60s (currently: ${tdrDelay}s)`n"
}
if ($tdrDdiDelay -lt 60 -or $tdrDdiDelay -eq 0) {
    $needsTdrUpdate = $true
    $tdrRecommendation += "  - TdrDdiDelay should be >= 60s (currently: ${tdrDdiDelay}s)`n"
}
if ($tdrLimitCount -lt 10 -or $tdrLimitCount -eq 0) {
    $needsTdrUpdate = $true
    $tdrRecommendation += "  - TdrLimitCount should be >= 10 (currently: ${tdrLimitCount})`n"
}
if ($tdrLimitTime -lt 120 -or $tdrLimitTime -eq 0) {
    $needsTdrUpdate = $true
    $tdrRecommendation += "  - TdrLimitTime should be >= 120s (currently: ${tdrLimitTime}s)`n"
}

if ($needsTdrUpdate) {
    Write-Host "WARNING: TDR settings may cause DLSS-NR timeouts on AMD GPUs!" -ForegroundColor Yellow
    Write-Host "Recommended changes:" -ForegroundColor Yellow
    Write-Host $tdrRecommendation -ForegroundColor Yellow
    Write-Host "To apply recommended TDR settings, run:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\Setup.TDRFix.ps1" -ForegroundColor Yellow
    Write-Host "  (Requires administrator privileges and a reboot to take effect)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: Envy-Diamond v1.0.0 patches watchdog timeouts in memory, but" -ForegroundColor Yellow
    Write-Host "proper TDR settings prevent system-level GPU timeouts under heavy load." -ForegroundColor Yellow
} else {
    Write-Host "TDR settings verified: Optimal for DLSS-NR workloads" -ForegroundColor Green
}

# Set GPU generation as a user environment variable for ASI plugin to read via GetEnvironmentVariableW
[Environment]::SetEnvironmentVariable("ENY_GPU_GEN", "RDNA$rdnaGen", "User")
Write-Host "Environment variable ENY_GPU_GEN=RDNA$rdnaGen set for User."

Write-Host 'Dynamic Pacing ASI plugin installed. Verify TDR settings above for optimal performance.'
