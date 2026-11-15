param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [ValidateSet('auto','dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll')]
    [string]$ProxyName='auto',
    [ValidateSet('auto','mochizuki','daniel','lmxxf')]
    [string]$NrBackend='auto',
    [Alias('DanielNrFile')][string]$NrDllPath,
    [string]$DependencyDirectory,
    [switch]$SkipDaniel080,
    [switch]$SkipAnrFg
)
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Find-VerifiedNrDll {
    param([string]$ExplicitPath, [string]$DepDir, [string]$GamePath, [string]$ScriptDir)
    $acceptedHashes = @{
        '2BC19BC09A7B89DD44F73E2AC0108FCC586E2154BDD0830F242F4F040E28789F' = '310.9.16.0'
        'E16BCF15E16E13F527491CDF7845B2FE6521A738D8F7C9C721866A8496E1FC8E' = '310.8.0.0'
    }
    function Test-NrCandidate([string]$Path) {
        if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
        $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
        return $acceptedHashes.ContainsKey($h)
    }

    if ($ExplicitPath) {
        if (-not (Test-NrCandidate $ExplicitPath)) {
            throw "O arquivo '$ExplicitPath' nao e um nvngx_dlssnr.dll suportado (310.9.16.0 ou 310.8.0.0 com SHA-256 verificado)."
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($DepDir) {
        $candidates.Add((Join-Path $DepDir 'nvngx_dlssnr.dll'))
        foreach ($h in $acceptedHashes.Keys) {
            $candidates.Add((Join-Path $DepDir "$($h.ToLowerInvariant())\nvngx_dlssnr.dll"))
        }
    }
    foreach ($base in @($GamePath, (Join-Path $GamePath 'AMDNR-NeuralHub-080\data'), $ScriptDir, (Join-Path $ScriptDir 'deps'), (Join-Path $ScriptDir 'cache'))) {
        if ($base) {
            $candidates.Add((Join-Path $base 'nvngx_dlssnr.dll'))
            $candidates.Add((Join-Path $base 'nvngx_dlssnr.dll.bak'))
        }
    }
    foreach ($c in $candidates) {
        if (Test-NrCandidate $c) { return $c }
    }
    $amdnrLocal = Join-Path $env:LOCALAPPDATA 'AMDNR'
    if (Test-Path -LiteralPath $amdnrLocal -PathType Container) {
        $found = Get-ChildItem -LiteralPath $amdnrLocal -Filter 'nvngx_dlssnr.dll' -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { Test-NrCandidate $_.FullName } | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

$game=(Resolve-Path -LiteralPath $GameDir).Path
if (!(Test-Path -LiteralPath $game -PathType Container)) {throw 'Informe a pasta do executavel do jogo.'}
$running=Get-Process -ErrorAction SilentlyContinue | Where-Object {try {$_.Path -and ([IO.Path]::GetDirectoryName($_.Path) -eq $game)} catch {$false}}
if ($running) {throw 'Feche o jogo antes de instalar.'}

# 1. Download AMD-NR, Mochi component, and optional Daniel 0.8.0 helper from GitHub
$tempDir = Join-Path $env:TEMP "ED2_Payload"
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir | Out-Null

$downloadSuccess = $false
$danielAsset = $null
try {
    Write-Host "Fetching latest releases from GitHub..."
    $ghHeaders = @{ 'User-Agent' = 'ED2-Installer' }
    $releasesUrl = "https://api.github.com/repos/3zwr1/AMD-NR---OptiScaler/releases?per_page=100"
    $rawReleases = Invoke-RestMethod -Uri $releasesUrl -Headers $ghHeaders
    $releases = @($rawReleases | Where-Object { -not $_.draft })
    $release = $releases | Where-Object { $_.assets | Where-Object { $_.name -match '^AMDNR-v.*\.zip$' } } | Select-Object -First 1
    if (-not $release) {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/3zwr1/AMD-NR---OptiScaler/releases/latest" -Headers $ghHeaders
        $releases = @($release)
    }

    $amdnrAsset = $release.assets | Where-Object { $_.name -match '^AMDNR-v.*\.zip$' } | Select-Object -First 1
    $mochiAsset = $release.assets | Where-Object { $_.name -match '^AMDNR-Mochi-.*-component\.zip$' } | Select-Object -First 1
    $runtimeAsset = $release.assets | Where-Object { $_.name -match '.*-Runtime\.zip$' } | Select-Object -First 1
    $danielRel = $releases | Where-Object { $_.assets | Where-Object { $_.name -match '^Daniel-0\.8\.0.*\.zip$' } } | Select-Object -First 1
    if ($danielRel) {
        $danielAsset = $danielRel.assets | Where-Object { $_.name -match '^Daniel-0\.8\.0.*\.zip$' } | Select-Object -First 1
    }

    $tag = $release.tag_name -replace '^Alpha|^v',''
    $localMatched = if ($tag) {
        Get-ChildItem -Path $PSScriptRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq "AMDNR-v$tag" } | Select-Object -First 1
    }

    if ($localMatched) {
        Write-Host "Using up-to-date local payload from $($localMatched.Name)..."
        New-Item -ItemType Directory -Path "$tempDir\amdnr" -Force | Out-Null
        Copy-Item -Path "$($localMatched.FullName)\*" -Destination "$tempDir\amdnr" -Recurse -Force
        $downloadSuccess = $true
    } elseif ($amdnrAsset) {
        Write-Host "Selected AMD-NR release: $($release.tag_name) ($($amdnrAsset.name))"
        Invoke-WebRequest -UseBasicParsing -Uri $amdnrAsset.browser_download_url -OutFile "$tempDir\amdnr.zip"
        if ($mochiAsset) {
            Write-Host "Downloading $($mochiAsset.name)..."
            Invoke-WebRequest -UseBasicParsing -Uri $mochiAsset.browser_download_url -OutFile "$tempDir\mochi.zip"
        }
        if ($runtimeAsset) {
            Write-Host "Downloading $($runtimeAsset.name)..."
            Invoke-WebRequest -UseBasicParsing -Uri $runtimeAsset.browser_download_url -OutFile "$tempDir\runtime.zip"
        }
        Write-Host "Extracting payloads..."
        Expand-Archive -Path "$tempDir\amdnr.zip" -DestinationPath "$tempDir\amdnr" -Force
        if (Test-Path "$tempDir\mochi.zip") {
            Expand-Archive -Path "$tempDir\mochi.zip" -DestinationPath "$tempDir\amdnr" -Force
        }
        if (Test-Path "$tempDir\runtime.zip") {
            Expand-Archive -Path "$tempDir\runtime.zip" -DestinationPath "$tempDir\runtime" -Force
        }
        $downloadSuccess = $true
    }
} catch {
    Write-Warning "Could not fetch online release: $_"
}

if (-not $downloadSuccess) {
    $localCached = Get-ChildItem -Path $PSScriptRoot -Filter "AMDNR-v*" -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if ($localCached) {
        Write-Host "Using cached local payload from $($localCached.Name)..."
        New-Item -ItemType Directory -Path "$tempDir\amdnr" -Force | Out-Null
        Copy-Item -Path "$($localCached.FullName)\*" -Destination "$tempDir\amdnr" -Recurse -Force
    } else {
        throw "Failed to download required binaries and no local cached payload was found."
    }
}

$isREEngine = (Get-ChildItem -LiteralPath $game -Filter 're_chunk_*.pak' -ErrorAction SilentlyContinue).Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $game 're9.exe'))
$isNMS = (Test-Path -LiteralPath (Join-Path $game 'NMS.exe'))
$candidates = @('dxgi.dll','winmm.dll','version.dll','winhttp.dll','wininet.dll','dbghelp.dll')
$existingProxies = foreach ($c in $candidates) {
    $candidatePath = Join-Path $game $c
    if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
        $vInfo = (Get-Item -LiteralPath $candidatePath).VersionInfo
        $isReShade = ($vInfo.FileDescription -match 'ReShade' -or $vInfo.ProductName -match 'ReShade' -or $vInfo.OriginalFilename -match 'ReShade')
        $isOpti = ($vInfo.FileDescription -match 'OptiScaler' -or $vInfo.ProductName -match 'OptiScaler' -or $vInfo.OriginalFilename -match 'OptiScaler')
        [pscustomobject]@{ Name = $c; Path = $candidatePath; IsReShade = $isReShade; IsOptiScaler = $isOpti }
    }
}

$optiProxies = @($existingProxies | Where-Object { -not $_.IsReShade })

if ($ProxyName -eq 'auto') {
    if ($optiProxies.Count -gt 1) {
        throw "Multiplos proxies encontrados: $($optiProxies.Name -join ', '). Remova-os primeiro ou especifique -ProxyName."
    }
    $proxyName = if ($optiProxies) {
        $optiProxies[0].Name
    } elseif ($existingProxies | Where-Object { $_.IsReShade -and $_.Name -eq 'dxgi.dll' }) {
        'winmm.dll'
    } elseif ($isNMS -or $isREEngine) {
        'version.dll'
    } else {
        'dxgi.dll'
    }
} else {
    $proxyName = $ProxyName
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
$optiSrc = Get-ChildItem -LiteralPath "$tempDir\amdnr" -Filter 'OptiScaler.dll' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $optiSrc) { throw "OptiScaler.dll / Optiscaler.dll not found in AMDNR payload." }
Install-File $optiSrc.FullName $proxyName
foreach($name in @('OptiScaler.ini','MochizukiNrRuntime.dll','dlssnr_amd_pass1.dll','dlssnr_amd_pass2.dll','dlssnr_amd_pass3.dll','dlssnr_on_amd_weights.bin','LmxxfNrRuntime.dll','LmxxfNrRuntime.pak','MOCHI-README.txt','MOCHI-SOURCE.txt','SOURCE-AVAILABILITY.txt')) {
    $src = if (Test-Path (Join-Path "$tempDir\amdnr" $name)) { Join-Path "$tempDir\amdnr" $name } else { Join-Path "$tempDir\runtime" $name }
    Install-File $src $name
}
foreach ($subDir in @('OptiScaler','FSR4Fast','AMDNR-ModelB','dlssnr-amd','model-tools','Licenses')) {
    $subPath = Join-Path "$tempDir\amdnr" $subDir
    if (Test-Path $subPath) {
        Get-ChildItem -LiteralPath $subPath -File -Recurse | ForEach-Object {
            $relative = $_.FullName.Substring($subPath.Length + 1)
            Install-File $_.FullName (Join-Path $subDir $relative)
        }
    }
}

$anrFgInstalled = $false
if (-not $SkipAnrFg) {
    try {
        Write-Host "Fetching latest Apex Neural Rendering (ANR FG) addon from GitHub..."
        $anrRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/apex-compute/ANR/releases/latest"
        $anrAsset = $anrRelease.assets | Where-Object { $_.name -match '^anr-fg-.*-addon\.zip$' } | Select-Object -First 1
        if ($anrAsset) {
            $anrZip = Join-Path $tempDir 'anr_addon.zip'
            Write-Host "Downloading $($anrAsset.name)..."
            Invoke-WebRequest -Uri $anrAsset.browser_download_url -OutFile $anrZip

            $shaAsset = $anrRelease.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' } | Select-Object -First 1
            if ($shaAsset) {
                $shaResp = Invoke-WebRequest -Uri $shaAsset.browser_download_url -UseBasicParsing
                $shaText = if ($shaResp.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($shaResp.Content) } else { [string]$shaResp.Content }
                $expectedLine = ($shaText -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($anrAsset.name) } | Select-Object -First 1
                if ($expectedLine -and ($expectedLine -match '^([0-9a-fA-F]{64})\s+')) {
                    $expectedHash = $Matches[1].ToUpperInvariant()
                    $actualHash = (Get-FileHash -LiteralPath $anrZip -Algorithm SHA256).Hash.ToUpperInvariant()
                    if ($actualHash -ne $expectedHash) {
                        throw "SHA-256 mismatch for $($anrAsset.name): expected $expectedHash, got $actualHash"
                    }
                    Write-Host "Verified ANR FG SHA-256 ($($anrRelease.tag_name))."
                }
            }

            $anrExtract = Join-Path $tempDir 'anr_addon'
            Expand-Archive -Path $anrZip -DestinationPath $anrExtract -Force
            $anrSrc = Join-Path $anrExtract 'Apex Neural Rendering FG'
            if (Test-Path -LiteralPath $anrSrc -PathType Container) {
                $existingNrFgIni = Join-Path $game 'OptiScaler\custom\Apex Neural Rendering FG\dlssg\nr_fg.ini'
                $preserveNrFgIni = Test-Path -LiteralPath $existingNrFgIni -PathType Leaf
                Get-ChildItem -LiteralPath $anrSrc -File -Recurse | ForEach-Object {
                    $rel = $_.FullName.Substring($anrSrc.Length + 1)
                    if ($preserveNrFgIni -and ($rel -ieq 'dlssg\nr_fg.ini')) { return }
                    Install-File $_.FullName (Join-Path 'OptiScaler\custom\Apex Neural Rendering FG' $rel)
                }
                $anrFgInstalled = $true
                Write-Host "Installed ANR FG ($($anrRelease.tag_name)) to OptiScaler\custom\Apex Neural Rendering FG."
            }
        }
    } catch {
        Write-Warning "Could not install optional ANR FG addon: $_"
    }
}

# 2. Optional NR Backends: Mochizuki weights & Daniel 0.8.0 (NeuralHub)
$verifiedNrDll = Find-VerifiedNrDll -ExplicitPath $NrDllPath -DepDir $DependencyDirectory -GamePath $game -ScriptDir $PSScriptRoot

$mochiWeightsSmall = Join-Path $game 'dlssnr-amd\dlssnr-small.bin'
$mochiWeightsAlt = Join-Path $game 'dlssnr-amd\dlssnr.bin'
if (-not (Test-Path -LiteralPath $mochiWeightsSmall -PathType Leaf) -and -not (Test-Path -LiteralPath $mochiWeightsAlt -PathType Leaf)) {
    $extractor = Join-Path $game 'model-tools\dlssnr_extract_model.exe'
    if ($verifiedNrDll -and (Test-Path -LiteralPath $extractor -PathType Leaf)) {
        Write-Host "Extracting Mochizuki NR weights from $verifiedNrDll..."
        $mochiOut = Join-Path $tempDir 'mochi_weights'
        New-Item -ItemType Directory -Path $mochiOut -Force | Out-Null
        & $extractor $verifiedNrDll $mochiOut
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "dlssnr_extract_model.exe returned exit code $LASTEXITCODE."
        } else {
            Get-ChildItem -LiteralPath $mochiOut -File -Recurse | ForEach-Object {
                $rel = $_.FullName.Substring($mochiOut.Length + 1)
                Install-File $_.FullName (Join-Path 'dlssnr-amd' $rel)
            }
        }
    }
}
$mochiReady = (Test-Path -LiteralPath (Join-Path $game 'MochizukiNrRuntime.dll') -PathType Leaf) -and
              ((Test-Path -LiteralPath $mochiWeightsSmall -PathType Leaf) -or (Test-Path -LiteralPath $mochiWeightsAlt -PathType Leaf))

$danielHostDll = Join-Path $game 'AMDNR-NeuralHub-080\neuralhub_host.dll'
$danielNrData  = Join-Path $game 'AMDNR-NeuralHub-080\data\nvngx_dlssnr.dll'
$daniel080Ready = (Test-Path -LiteralPath $danielHostDll -PathType Leaf) -and (Test-Path -LiteralPath $danielNrData -PathType Leaf)

if (-not $SkipDaniel080 -and -not $daniel080Ready) {
    if ($verifiedNrDll -and $danielAsset) {
        try {
            Write-Host "Downloading $($danielAsset.name) for Daniel 0.8.0 preparation..."
            $danielZip = Join-Path $tempDir 'daniel080.zip'
            Invoke-WebRequest -UseBasicParsing -Uri $danielAsset.browser_download_url -OutFile $danielZip
            $danielExtract = Join-Path $tempDir 'daniel080'
            Expand-Archive -Path $danielZip -DestinationPath $danielExtract -Force
            $prepScript = Join-Path $danielExtract 'Prepare-Daniel080.ps1'
            $prepOut = Join-Path $tempDir 'daniel080_out'
            New-Item -ItemType Directory -Path $prepOut -Force | Out-Null

            $prepArgs = @{
                NrFile          = $verifiedNrDll
                OutputDirectory = $prepOut
            }
            if ($DependencyDirectory -and (Test-Path -LiteralPath $DependencyDirectory -PathType Container)) {
                $prepArgs['DependencyDirectory'] = $DependencyDirectory
            }
            & $prepScript @prepArgs

            $preparedHub = Join-Path $prepOut 'AMDNR-NeuralHub-080'
            if (Test-Path -LiteralPath $preparedHub -PathType Container) {
                Get-ChildItem -LiteralPath $preparedHub -File -Recurse | ForEach-Object {
                    $rel = $_.FullName.Substring($preparedHub.Length + 1)
                    Install-File $_.FullName (Join-Path 'AMDNR-NeuralHub-080' $rel)
                }
                $daniel080Ready = (Test-Path -LiteralPath $danielHostDll -PathType Leaf) -and (Test-Path -LiteralPath $danielNrData -PathType Leaf)
                if ($daniel080Ready) {
                    Write-Host "Daniel 0.8.0 (AMDNR-NeuralHub-080) prepared and installed."
                }
            }
        } catch {
            if ($NrBackend -eq 'daniel') { throw }
            Write-Warning "Could not prepare optional Daniel 0.8.0 runtime: $_"
        }
    } elseif ($NrBackend -eq 'daniel') {
        throw "Daniel 0.8.0 requer nvngx_dlssnr.dll verificado (versao 310.9.16.0 ou 310.8.0.0) via -NrDllPath ou -DependencyDirectory. Veja https://github.com/danielblnc/DLSS-NR-on-AMD/releases"
    }
}

if ($NrBackend -eq 'mochizuki' -and -not $mochiReady) {
    Write-Warning "MochizukiNrRuntime.dll instalado, mas os pesos extraidos (dlssnr-amd\dlssnr-small.bin) ainda exigem nvngx_dlssnr.dll (310.9.16.0 ou 310.8.0.0) via -NrDllPath ou AMDNR Launcher."
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
    $nl = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = $content -split "`r?`n"
    $out = [System.Collections.Generic.List[string]]::new()
    $escapedKey = [regex]::Escape($key)
    $inSection = $false
    $sectionSeen = $false
    $keyHandled = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*\[([^\]]+)\]') {
            if ($inSection -and -not $keyHandled) {
                $insertIdx = $out.Count
                while ($insertIdx -gt 0 -and [string]::IsNullOrWhiteSpace($out[$insertIdx - 1])) { $insertIdx-- }
                $out.Insert($insertIdx, "$key=$val")
                $keyHandled = $true
            }
            $inSection = ($Matches[1].Trim() -ieq $section)
            if ($inSection) { $sectionSeen = $true }
            $out.Add($line)
            continue
        }
        if ($inSection -and $line -match "^\s*$escapedKey\s*=") {
            if (-not $keyHandled) {
                $out.Add("$key=$val")
                $keyHandled = $true
            }
            continue
        }
        $out.Add($line)
    }

    if ($inSection -and -not $keyHandled) {
        $insertIdx = $out.Count
        while ($insertIdx -gt 0 -and [string]::IsNullOrWhiteSpace($out[$insertIdx - 1])) { $insertIdx-- }
        $out.Insert($insertIdx, "$key=$val")
    } elseif (-not $sectionSeen) {
        if ($out.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($out[$out.Count - 1])) { $out.Add('') }
        $out.Add("[$section]")
        $out.Add("$key=$val")
    }

    return ($out -join $nl)
}

$iniDest = Join-Path $game 'OptiScaler.ini'
$iniContent = Get-Content $iniDest -Raw

$iniContent = Set-IniValue $iniContent 'FrameGen' 'SkipResizeBuffers' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'PreserveSwapChain' 'false'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifyBufferState' 'true'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'ModifySCIndex'     'true'
$iniContent = Set-IniValue $iniContent 'FrameGen' 'SkipReset'         'true'
$iniContent = Set-IniValue $iniContent 'Inputs'   'SkipReset'         'true'

if ($anrFgInstalled -and -not $isREEngine) {
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'FGInput'            'nvngxfg'
    $iniContent = Set-IniValue $iniContent 'FrameGen' 'FGNvngxReplacement' 'Apex Neural Rendering FG'
}

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
    $iniContent = Set-IniValue $iniContent 'Menu' 'OverlayMenu' 'true'
    $iniContent = Set-IniValue $iniContent 'Menu' 'ShortcutKey' '0x2D'
    $iniContent = Set-IniValue $iniContent 'Menu' 'MenuKey'     '0x2D'
}
$iniContent = Set-IniValue $iniContent 'Framerate' 'FramerateLimit' '0.0'

$effectiveBackend = if ($NrBackend -ne 'auto') {
    $NrBackend
} elseif ($mochiReady) {
    'mochizuki'
} elseif ($daniel080Ready) {
    'daniel'
} elseif (Test-Path -LiteralPath (Join-Path $game 'dlssnr_amd_pass1.dll') -PathType Leaf) {
    'daniel'
} else {
    'lmxxf'
}

$iniContent = Set-IniValue $iniContent 'DlssNr' 'NrBackend' $effectiveBackend
if ($daniel080Ready) {
    $iniContent = Set-IniValue $iniContent 'DLSS' 'ForceDlssSr' 'true'
    $iniContent = Set-IniValue $iniContent 'DLSS' 'NeuralHubEnabled' 'true'
    $iniContent = Set-IniValue $iniContent 'DLSS' 'NeuralHubNrEnabled' $(if ($effectiveBackend -eq 'daniel') { 'true' } else { 'false' })
} else {
    # Prevent NHUB080 startup AppHangB1 when AMDNR-NeuralHub-080 is absent
    $iniContent = Set-IniValue $iniContent 'DLSS' 'ForceDlssSr' 'auto'
    $iniContent = Set-IniValue $iniContent 'DLSS' 'NeuralHubEnabled' 'false'
    $iniContent = Set-IniValue $iniContent 'DLSS' 'NeuralHubNrEnabled' 'false'
}

# Configure AMD-NR Model Interleave for Real-Time performance
$iniContent = Set-IniValue $iniContent 'DlssNr' 'AmdInterleave' '0'
$iniContent = Set-IniValue $iniContent 'Spoofing' 'Dxgi' 'true'
$iniContent | Set-Content $iniDest
Write-Host "OptiScaler.ini tuned for RDNA $rdnaGen (NrBackend=$effectiveBackend, Daniel080=$daniel080Ready, MochiWeights=$mochiReady)."

Write-Host "Instalado em: $game"
Write-Host "Proxy: $proxyName"
Write-Host "Backup em: $backup"

# Clean up temp
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host 'AMD-NR runtime configured successfully from remote sources.'

