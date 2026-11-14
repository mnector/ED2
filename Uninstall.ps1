param(
    [Parameter(Mandatory=$false)]
    [string]$game
)

if (-not $game) {
    Write-Host "Please provide the path to the game executable or directory to uninstall from."
    exit 1
}

if (Test-Path $game -PathType Leaf) {
    $game = Split-Path $game
}

Write-Host "Uninstalling ED2 / AMD-NR from: $game"

$filesToRemove = @(
    "dxgi.dll",
    "winmm.dll",
    "nvapi64.dll",
    "OptiScaler.ini",
    "OptiScaler.log",
    "dlssnr_amd_pass1.dll",
    "dlssnr_amd_pass2.dll",
    "dlssnr_amd_pass3.dll",
    "dlssnr_on_amd_weights.bin",
    "LmxxfNrRuntime.dll",
    "LmxxfNrRuntime.pak",
    "danielblnc_ATTRIBUTION.txt",
    "nvngx.dll"
)

# Check for automated backup and restore original files
$backupDirs = Get-ChildItem -LiteralPath $game -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "^backup-amd" } | Sort-Object LastWriteTime -Descending
if ($backupDirs) {
    $latestBackup = $backupDirs[0]
    $manifestPath = Join-Path $latestBackup.FullName "manifest.json"
    if (Test-Path $manifestPath) {
        Write-Host "Found backup manifest in $($latestBackup.Name). Restoring original files..."
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            foreach ($entry in $manifest) {
                $targetFile = Join-Path $game $entry.File
                $backupFile = Join-Path $latestBackup.FullName $entry.File
                if ($entry.Existed -and (Test-Path $backupFile)) {
                    Copy-Item -LiteralPath $backupFile -Destination $targetFile -Force
                    Write-Host "Restored original: $($entry.File)"
                } else {
                    if (Test-Path $targetFile) {
                        Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
                        Write-Host "Removed installed: $($entry.File)"
                    }
                }
            }
        } catch {
            Write-Warning "Could not parse manifest: $_"
        }
    }
}

foreach ($file in $filesToRemove) {
    $path = Join-Path $game $file
    if (Test-Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
        Write-Host "Removed: $file"
    }
}

$optiDir = Join-Path $game "OptiScaler"
if (Test-Path $optiDir) {
    Remove-Item -Path $optiDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed: OptiScaler directory"
}

Write-Host "Uninstallation complete. Game restored to original state."

