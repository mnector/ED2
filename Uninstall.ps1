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

Write-Host "Uninstallation complete."

