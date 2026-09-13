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
$proxies=@('dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll') | ForEach-Object {
    $candidate=Join-Path $game $_
    if(Test-Path -LiteralPath $candidate -PathType Leaf) {
        $item=Get-Item -LiteralPath $candidate
        if($item.VersionInfo.ProductName -eq 'OptiScaler' -or $item.VersionInfo.FileDescription -eq 'OptiScaler') {$item.Name}
    }
}
if(@($proxies).Count -gt 1){throw ('Mais de um proxy OptiScaler encontrado: '+($proxies -join ', ')+'. Mantenha apenas o proxy que deseja usar antes de atualizar.')}
$proxyName=if($ProxyName -eq 'auto') {
    if(@($proxies).Count -eq 1){@($proxies)[0]}else{'dxgi.dll'}
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

# ── TDR Registry Configuration ──────────────────────────────────────────────
# AMD HIP neural-rendering kernels run as generic GPU compute.  The default
# Windows TDR timeout (TdrDelay=2s) is too short for heavy inference passes,
# causing the driver to kill the kernel mid-execution.  OptiScaler recovers
# ("retry in 1s with fresh history"), but the user sees stutters and quality
# loss.  Raising these values gives the HIP backend the headroom it needs.
$tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$tdrBackup = @{}
foreach ($key in @('TdrDelay','TdrDdiDelay','TdrLimitCount','TdrLimitTime')) {
    $current = (Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction SilentlyContinue).$key
    $tdrBackup[$key] = $current   # may be $null (default)
}
# Persist previous TDR values so they can be restored on uninstall.
$tdrBackup | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'tdr_backup.json')

$tdrSettings = @{
    TdrDelay      = 8     # Default 2s  → 8s   for HIP kernel completion
    TdrDdiDelay   = 10    # Default 5s  → 10s  for DDI callbacks
    TdrLimitCount = 10    # Default 5   → 10   tolerated TDRs before crash
    TdrLimitTime  = 120   # Default 60s → 120s observation window
}
foreach ($key in $tdrSettings.Keys) {
    Set-ItemProperty -Path $tdrPath -Name $key -Value $tdrSettings[$key] -Type DWord -ErrorAction SilentlyContinue
}
Write-Host 'TDR registry configured for AMD HIP compute workloads.'

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
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\[') {
            $inSection = ($lines[$i].Trim() -eq "[$section]")
        }
        if ($inSection -and $lines[$i] -match "^$key=") {
            $lines[$i] = "$key=$value"
            return $lines
        }
    }
    return $lines
}

# ── DlssNr parameters based on RDNA generation ──
switch ($rdnaGen) {
    4 {
        # RDNA 4: Full neural rendering support
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdModelScale'              '1'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLighting'          'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLightingStrength'  '0.5'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Passes'                     '1'
    }
    3 {
        # RDNA 3: Light NR, reduced neural lighting to avoid timeouts
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdModelScale'              '1'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLighting'          'true'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdNeuralLightingStrength'  '0.3'
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Passes'                     '1'
    }
    default {
        # RDNA 2 or unknown: Disable NR entirely to prevent timeout storms
        $iniContent = Set-IniValue $iniContent 'DlssNr' 'Enabled'                    'false'
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

# ── Resource Barriers: always-on for UE5 AMD ──
$iniContent = Set-IniValue $iniContent 'Hotfix' 'ColorResourceBarrier'        '4'
$iniContent = Set-IniValue $iniContent 'Hotfix' 'MotionVectorResourceBarrier' '8'

# ── Framerate: remove the daemon's static limit ──
$iniContent = Set-IniValue $iniContent 'Framerate' 'FramerateLimit' '0.0'

$iniContent | Set-Content $iniDest
Write-Host "OptiScaler.ini tuned for RDNA $rdnaGen."

Write-Host "Instalado em: $game"
Write-Host "Proxy: $proxyName"
Write-Host "Backup em: $backup"
Write-Host 'TDR configurado. Ative FSR no jogo. Abra o menu do OptiScaler com Insert.'
Write-Host 'Reinicie o computador se for a primeira vez que executa o Envy-Diamond.'

