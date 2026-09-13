param(
    [string]$GameDir = $PSScriptRoot
)

$iniPath = Join-Path $GameDir "OptiScaler.ini"
$logPath = Join-Path $GameDir "dlssnr_on_amd.log"
$presrLogPath = Join-Path $GameDir "amd_presr.log"

if (-not (Test-Path $iniPath)) {
    Write-Host "OptiScaler.ini not found in $GameDir."
    exit 1
}

$minFPS = 45
$maxFPS = 120
$stepDownPercent = 0.08
$stepUpPercent = 0.02
$upDelayMs = 8000

function Get-CurrentLimit {
    $content = Get-Content $iniPath -ErrorAction SilentlyContinue
    $match = $content | Select-String -Pattern "^FramerateLimit=([0-9\.]+)"
    if ($match) {
        return [math]::Round([double]$match.Matches.Groups[1].Value)
    }
    return $maxFPS
}

function Set-CurrentLimit([int]$newLimit) {
    if ($newLimit -lt $minFPS) { $newLimit = $minFPS }
    if ($newLimit -gt $maxFPS) { $newLimit = $maxFPS }
    
    $content = Get-Content $iniPath -ErrorAction SilentlyContinue
    $replaced = $false
    for ($i=0; $i -lt $content.Length; $i++) {
        if ($content[$i] -match "^FramerateLimit=") {
            $content[$i] = "FramerateLimit=$newLimit"
            $replaced = $true
        }
    }
    if (-not $replaced) {
        for ($i=0; $i -lt $content.Length; $i++) {
            if ($content[$i] -match "^\[Framerate\]") {
                $content[$i] = "[Framerate]
FramerateLimit=$newLimit"
                $replaced = $true
                break
            }
        }
    }
    if ($replaced) {
        $content | Set-Content $iniPath -ErrorAction SilentlyContinue
        Write-Host "FramerateLimit adjusted to $newLimit"
    }
}

$lastSpikeTime = Get-Date

Write-Host "Envy-Diamond Dynamic Pacing Daemon Started."
Write-Host "Monitoring logs in $GameDir..."

$currentLimit = Get-CurrentLimit
if ($currentLimit -eq 0 -or $currentLimit -lt $minFPS) {
    Set-CurrentLimit $maxFPS
}

$fs1 = $null; $reader1 = $null
$fs2 = $null; $reader2 = $null

try {
    if (Test-Path $logPath) {
        $fs1 = New-Object IO.FileStream($logPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $fs1.Seek(0, [IO.SeekOrigin]::End) | Out-Null
        $reader1 = New-Object IO.StreamReader($fs1)
    }
    
    if (Test-Path $presrLogPath) {
        $fs2 = New-Object IO.FileStream($presrLogPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        $fs2.Seek(0, [IO.SeekOrigin]::End) | Out-Null
        $reader2 = New-Object IO.StreamReader($fs2)
    }
    
    while ($true) {
        $spikeDetected = $false
        
        if ($reader1) {
            while (($line = $reader1.ReadLine()) -ne $null) {
                if ($line -match "timeout" -or $line -match "SPIKE" -or $line -match "skipped") { $spikeDetected = $true }
            }
        }
        
        if ($reader2) {
            while (($line = $reader2.ReadLine()) -ne $null) {
                if ($line -match "timeout" -or $line -match "skipped") { $spikeDetected = $true }
            }
        }
        
        if ($spikeDetected) {
            $lastSpikeTime = Get-Date
            $currentLimit = Get-CurrentLimit
            $newLimit = [math]::Floor($currentLimit * (1 - $stepDownPercent))
            if (($currentLimit - $newLimit) -lt 1) { $newLimit = $currentLimit - 1 }
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Spike detected! Lowering limit to $newLimit"
            Set-CurrentLimit $newLimit
        }
        else {
            $elapsed = (Get-Date) - $lastSpikeTime
            if ($elapsed.TotalMilliseconds -ge $upDelayMs) {
                $currentLimit = Get-CurrentLimit
                if ($currentLimit -lt $maxFPS) {
                    $newLimit = [math]::Ceiling($currentLimit * (1 + $stepUpPercent))
                    if (($newLimit - $currentLimit) -lt 1) { $newLimit = $currentLimit + 1 }
                    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Stable. Increasing limit to $newLimit"
                    Set-CurrentLimit $newLimit
                }
                $lastSpikeTime = Get-Date
            }
        }
        
        Start-Sleep -Milliseconds 250
    }
}
finally {
    if ($reader1) { $reader1.Dispose() }
    if ($fs1) { $fs1.Dispose() }
    if ($reader2) { $reader2.Dispose() }
    if ($fs2) { $fs2.Dispose() }
}
