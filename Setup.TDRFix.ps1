<#
.SYNOPSIS
    Fixes Windows TDR settings for AMD DLSS-NR

.DESCRIPTION
    Configures TDR registry values to prevent AMD GPU timeouts during neural rendering.
    Requires administrator privileges and a reboot.
#>

[CmdletBinding()]
param(
    [switch]$RestoreBackup,
    [string]$BackupPath
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click and select Run as Administrator" -ForegroundColor Red
    exit 1
}

$tdrPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
$tdrKeys = @{
    "TdrDelay" = 60
    "TdrDdiDelay" = 60
    "TdrLimitCount" = 10
    "TdrLimitTime" = 120
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
        Write-Host "TDR settings restored. Please reboot." -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "ERROR: Failed to restore backup" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Configuring TDR settings for AMD DLSS-NR workloads..."
Write-Host "====================================================="
Write-Host ""

Write-Host "Setting recommended TDR values:" -ForegroundColor Cyan
foreach ($key in $tdrKeys.Keys) {
    $newValue = $tdrKeys[$key]
    try {
        Set-ItemProperty -Path $tdrPath -Name $key -Value $newValue -Force | Out-Null
        Write-Host "  $key = $newValue" -ForegroundColor Yellow
    } catch {
        Write-Host "  ERROR setting $key" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "IMPORTANT: Reboot required for changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "To undo these changes:" -ForegroundColor Cyan
Write-Host "  .\Setup.TDRFix.ps1 -RestoreBackup -BackupPath <path-to-backup>" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verifying..."
$verified = $true
foreach ($key in $tdrKeys.Keys) {
    try {
        $actual = (Get-ItemProperty -Path $tdrPath -Name $key -ErrorAction Stop).$key
        if ($actual -ne $tdrKeys[$key]) {
            Write-Host "  WARNING: $key is $actual, expected $($tdrKeys[$key])" -ForegroundColor Yellow
            $verified = $false
        }
    } catch {
        Write-Host "  ERROR: Could not verify $key" -ForegroundColor Red
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
