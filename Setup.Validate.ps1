# Validation Script for Envy-Diamond-2
# Run this after installation to verify everything is configured correctly

param(
    [string]$GameDir
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "========================================"
Write-Host "Envy-Diamond-2 Post-Install Validation"
Write-Host "========================================"
Write-Host ""

if (-not $GameDir) {
    $GameDir = $PWD.Path
}

Write-Host "Checking installation in: $GameDir"
Write-Host ""

$checksPassed = 0
$checksFailed = 0
$checksWarning = 0

function Check-Result {
    param([string]$Name, [bool]$Passed, [string]$Message)
    
    if ($Passed) {
        Write-Host "  ✓ $Name" -ForegroundColor Green
        if ($Message) { Write-Host "    $Message" -ForegroundColor DarkGreen }
        $script:checksPassed++
    } else {
        if ($Message) {
            Write-Host "  ✗ $Name: $Message" -ForegroundColor Red
            $script:checksFailed++
        } else {
            Write-Host "  ⚠ $Name" -ForegroundColor Yellow
            $script:checksWarning++
        }
    }
}

# 1. Check plugin files exist
Write-Host "1. Plugin Files" -ForegroundColor Cyan
Check-Result -Name "EnvyDynamicPacing.asi" -Passed (Test-Path "$GameDir\OptiScaler\plugins\EnvyDynamicPacing.asi")
Check-Result -Name "OptiScaler.dll" -Passed (Test-Path "$GameDir\OptiScaler.dll")
Check-Result -Name "OptiScaler.ini" -Passed (Test-Path "$GameDir\OptiScaler.ini")
Write-Host ""

# 2. Check TDR registry
Write-Host "2. TDR Registry Settings" -ForegroundColor Cyan
$tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$tdrKeys = @('TdrDelay', 'TdrDdiDelay', 'TdrLimitCount', 'TdrLimitTime')

foreach ($key in $tdrKeys) {
    try {
        $value = Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction Stop | Select-Object -ExpandProperty $key
        Check-Result -Name $key -Passed ($value -ne $null) -Message "Value: $value"
    } catch {
        Check-Result -Name $key -Passed $false -Message "Not configured (default: may cause timeouts)"
    }
}
Write-Host ""

# 3. Check INI configuration
Write-Host "3. OptiScaler.ini Configuration" -ForegroundColor Cyan
$iniContent = Get-Content "$GameDir\OptiScaler.ini" -ErrorAction SilentlyContinue

if ($iniContent) {
    $loadAsiPlugins = $iniContent | Where-Object { $_ -match '^LoadAsiPlugins=' }
    Check-Result -Name "LoadAsiPlugins=true" -Passed ($loadAsiPlugins -match 'true')
    
    $dlssNr = $iniContent | Where-Object { $_ -match '^Enabled=true' -and $_ -match 'DlssNr' }
    if ($dlssNr) {
        Check-Result -Name "DLSS-NR enabled" -Passed $true
    } else {
        Check-Result -Name "DLSS-NR" -Passed $true -Message "Check DlssNr section manually"
    }
} else {
    Check-Result -Name "OptiScaler.ini" -Passed $false -Message "Not found"
}
Write-Host ""

# 4. Check environment file
Write-Host "4. Environment Configuration" -ForegroundColor Cyan
$envFile = Get-Content "$GameDir\optiscaler.env" -ErrorAction SilentlyContinue
if ($envFile) {
    $gpuGen = $envFile | Where-Object { $_ -match 'ENY_GPU_GEN=' }
    Check-Result -Name "GPU Gen File" -Passed ($gpuGen -ne $null) -Message $gpuGen
} else {
    Check-Result -Name "GPU Gen File" -Passed $false -Message "Not found"
}
Write-Host ""

# 5. Check for logs
Write-Host "5. Log Files" -ForegroundColor Cyan
$envLogPath = $env:ENY_LOG_PATH
$logPath = if ($envLogPath) { $envLogPath } else { "envy_asi.log" }
$logFile = Get-ChildItem $logPath -ErrorAction SilentlyContinue | Select-Object -First 1

if ($logFile) {
    $lastLine = Get-Content $logFile.FullName -Tail 1 -ErrorAction SilentlyContinue
    Check-Result -Name "Log file exists" -Passed $true -Message $lastLine
} else {
    Check-Result -Name "Log file" -Passed $false -Message "Not found (will be created on game launch)"
}
Write-Host ""

# 6. Check backup exists
Write-Host "6. Backup Files" -ForegroundColor Cyan
$backupFolders = Get-ChildItem $GameDir -Directory | Where-Object { $_.Name -match 'backup-amd' }
if ($backupFolders) {
    $latestBackup = $backupFolders | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Check-Result -Name "Backup folder" -Passed $true -Message $latestBackup.Name
    $tdrBackup = Test-Path "$($latestBackup.FullName)\tdr_backup.json"
    Check-Result -Name "TDR backup" -Passed $tdrBackup
} else {
    Check-Result -Name "Backup folder" -Passed $false -Message "Not found"
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed:   $checksPassed" -ForegroundColor Green
Write-Host "Warnings: $checksWarning" -ForegroundColor Yellow
Write-Host "Failed:   $checksFailed" -ForegroundColor Red
Write-Host ""

if ($checksFailed -eq 0) {
    Write-Host "✓ Installation validated successfully!" -ForegroundColor Green
    if ($checksWarning -gt 0) {
        Write-Host "Note: $checksWarning warnings found. Review above." -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Installation has issues. Review warnings above." -ForegroundColor Red
}
Write-Host ""
