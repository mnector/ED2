<#
.SYNOPSIS
    Fixes Windows TDR (Timeout Detection and Recovery) registry settings for AMD DLSS-NR

.DESCRIPTION
    This script configures Windows TDR registry values to prevent AMD HIP compute kernel
    timeouts during heavy neural rendering passes. Recommended for Envy-Diamond-2 users
    experiencing GPU-related timeouts under heavy loads.

    Requires administrator privileges and a reboot to take effect.
#>

[CmdletBinding()]
param(
    [switch]$RestoreBackup,
    [string]$BackupPath
)

$ErrorActionPreference = 'Stop'

# Check for administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as Administrator'" -ForegroundColor Red
    exit 1
}

$tdrPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$tdrKeys = @{
    'TdrDelay' = 8          # Timeout in seconds (was 2s default)
    'TdrDdiDelay' = 10      # DDI callback margin (was 5s default)
    'TdrLimitCount' = 10    # Tolerance before crash (was 5 default)
    'TdrLimitTime' = 120    # Observation window in seconds (was 60s default)
}

if ($RestoreBackup) {
    if (-not $BackupPath) {
        Write-Host "ERROR: Please specify backup path with -BackupPath" -ForegroundColor Red
        exit 1
    }
    
    if (-not (Test-Path $BackupPath)) {
        Write-Host "ERROR: Backup file not found: $BackupPath" -ForegroundColor Red
        exit 1
    }
    
    try {
        $backup = Get-Content $BackupPath | ConvertFrom-Json
        foreach ($key in $backup.PSObject.Properties.Name) {
            if ($backup.$key -ne $null) {
                Set-ItemProperty -Path $tdrPath -Name $key -Value $backup.$key -Force | Out-Null
                Write-Host "Restored $key = $($backup.$key)"
            }
        }
        Write-Host ""
        Write-Host "TDR settings restored. Please reboot for changes to take effect." -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "ERROR: Failed to restore backup: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Configuring TDR settings for AMD DLSS-NR workloads..."
Write-Host "====================================================="
Write-Host ""

# Get current values
$currentValues = @{}
foreach ($key in $tdrKeys.Keys) {
    try {
        $currentValues[$key] = (Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction Stop).$key
    } catch {
        $currentValues[$key] = $null
    }
}

# Apply new values
Write-Host "Setting recommended TDR values:" -ForegroundColor Cyan
foreach ($key in $tdrKeys.Keys) {
    $oldValue = $currentValues[$key]
    $newValue = $tdrKeys[$key]
    
    if ($oldValue -eq $newValue) {
        Write-Host "  $key = $newValue (already set)" -ForegroundColor Green
    } else {
        try {
            Set-ItemProperty -Path $tdrPath -Name $key -Value $newValue -Force | Out-Null
            Write-Host "  $key = $oldValue -> $newValue" -ForegroundColor Yellow
        } catch {
            Write-Host "  ERROR setting $key: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "IMPORTANT: You must reboot your system for these changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "To undo these changes, run:" -ForegroundColor Cyan
Write-Host "  .\Setup.TDRFix.ps1 -RestoreBackup -BackupPath <path-to-backup>" -ForegroundColor Cyan
Write-Host ""

# Verify changes
Write-Host "Verifying registry changes..."
$verified = $true
foreach ($key in $tdrKeys.Keys) {
    try {
        $actual = (Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction Stop).$key
        if ($actual -ne $tdrKeys[$key]) {
            Write-Host "  WARNING: $key is $actual, expected $($tdrKeys[$key])" -ForegroundColor Yellow
            $verified = $false
        }
    } catch {
        Write-Host "  ERROR: Could not verify $key: $_" -ForegroundColor Red
        $verified = $false
    }
}

Write-Host ""
if ($verified) {
    Write-Host "SUCCESS: All TDR settings configured correctly!" -ForegroundColor Green
    Write-Host "Please reboot to apply changes." -ForegroundColor Green
} else {
    Write-Host "Some settings may not have been applied correctly." -ForegroundColor Red
}
