<div align="center">

# 💎 Envy-Diamond-2 💎

**Advanced Neural Rendering & Frame Generation Translation Layer for AMD GPUs**

[![Release](https://img.shields.io/github/v/release/mnector/Envy-Diamond?style=for-the-badge&color=blue)](https://github.com/mnector/Envy-Diamond/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?style=for-the-badge)]()
[![GPU](https://img.shields.io/badge/GPU-AMD%20Radeon-red?style=for-the-badge)]()
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://paypal.me/mnecstream)

Envy-Diamond-2 unlocks the true power of DLSS and OptiScaler features on AMD hardware, injecting a custom proxy to translate calls and deliver massive framerate uplifts!

*If this mod saved your framerate, consider buying me a coffee to support future development!*

<a href="https://paypal.me/mnecstream" target="_blank"><img src="https://www.paypalobjects.com/webstatic/mktg/logo/pp_cc_mark_111x69.jpg" alt="Donate with PayPal" width="100"/></a>

</div>

---

## 🚀 What's New in v1.0.5+ (Online Installer, ANR FG Included & R22+ Support)

- **⚡ Apex Neural Rendering (`ANR FG`) Included Out-of-the-Box:** `Setup.Install.ps1` now automatically fetches the latest official **[apex-compute/ANR](https://github.com/apex-compute/ANR)** Frame Generation addon (`anr-fg-*-addon.zip`), verifies its **SHA-256** checksum against `SHA256SUMS.txt`, installs it under `OptiScaler\custom\Apex Neural Rendering FG`, and sets `[FrameGen] FGInput=nvngxfg` & `FGNvngxReplacement=Apex Neural Rendering FG` so you get **DLSS 5 visuals (AMD-NR)** + **Vulkan neural Frame Generation (ANR FG)** in one click (verified on RDNA 4 in *GTA V Enhanced*; pass `-SkipAnrFg` if you want to opt out, and RE Engine keeps RTX 3090 isolation).
- **⚖️ Legal & License Compliance:** ED2 is 100% compliant and respects the licensing of third-party developers. It does not bundle copyrighted or upstream binaries in this repository.
- **🌐 Online Automated Installer (with Local Fallback):** `Setup.Install.ps1` fetches the latest official releases from **[3zwr1/AMD-NR---OptiScaler](https://github.com/3zwr1/AMD-NR---OptiScaler)** (GPL-3.0), **[danielblnc/DLSS-NR-on-AMD](https://github.com/danielblnc/DLSS-NR-on-AMD)** (All Rights Reserved), and **[apex-compute/ANR](https://github.com/apex-compute/ANR)** directly from GitHub at runtime (with local fallback to cached `AMDNR-v*` folders if GitHub is unreachable).
- **🧠 Full AMD-NR R22+ Runtime Deployment:** Installs `MochizukiNrRuntime.dll`, `dlssnr-amd/`, `FSR4Fast/`, `AMDNR-ModelB/`, `LmxxfNrRuntime.*`, and `dlssnr_amd_pass1..3.dll` alongside `OptiScaler`.
- **📝 Clean Line-by-Line INI Updater (`Set-IniValue`):** Replaced legacy regex INI edits with a line-by-line parser that updates keys in place without duplicates, preventing trailing `= auto` entries from overriding `[Spoofing] Dxgi = true`, `[FrameGen] SkipReset = true`, or `[Menu] OverlayMenu = true`.
- **🛡️ Zero Registry Modifications:** Invasive Windows TDR registry changes have been completely eliminated. No system restarts required, zero OS-level footprint.
- **🎨 Smart ReShade Coexistence:** Automatically detects existing ReShade proxies (such as `dxgi.dll`) and seamlessly assigns alternative proxy chains (`winmm.dll` or `version.dll`) so you can run ReShade and ED2 together without crashes.
- **📦 Non-Destructive Backup & 1-Click Restore:** Every installation creates a timestamped backup with `manifest.json` recording original file hashes. Run `Uninstall.ps1` at any time to restore your game to its exact original state.
- **🤝 Proper Attribution:** Full credit and gratitude belong to **3zwr1**, **Daniel Blanco (`danielblnc`)**, **Apex Compute (`ANR`)**, **Kien (`lmxxf`)**, **mochizuki0323**, and the **OptiScaler** contributors (see [Credits & Upstream Licenses](#-credits-acknowledgments--upstream-licenses)). ED2 acts strictly as an automated installer and configuration wrapper.

---

## 🎥 See it in Action

<table>
  <tr>
    <td align="center" width="50%">
      <b>🚗 Grand Theft Auto V Enhanced (Story Mode)</b><br>
      <i>DirectX 12 Streamline Interception, DLSS 5 & BattlEye Bypass</i><br><br>
      <a href="https://www.youtube.com/watch?v=kiMOxXV-ibY">
        <img src="https://img.youtube.com/vi/kiMOxXV-ibY/maxresdefault.jpg" alt="GTA V Enhanced Showcase" width="100%"/>
      </a><br>
      <a href="https://www.youtube.com/watch?v=kiMOxXV-ibY">▶ Watch on YouTube</a>
    </td>
    <td align="center" width="50%">
      <b>🧟 Resident Evil Requiem (BIOHAZARD requiem)</b><br>
      <i>DLSS 5 Neural Tunneling, Multi-Pass Inference & RE Engine Stability</i><br><br>
      <a href="https://www.youtube.com/watch?v=Bzbo73zTuVA">
        <img src="https://img.youtube.com/vi/Bzbo73zTuVA/maxresdefault.jpg" alt="Resident Evil Requiem Showcase" width="100%"/>
      </a><br>
      <a href="https://www.youtube.com/watch?v=Bzbo73zTuVA">▶ Watch on YouTube</a>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <b>🐾 Palworld</b><br>
      <i>Zero Stutters with The Digital Bottomless Pit Watchdog</i><br><br>
      <a href="https://www.youtube.com/watch?v=C_uBqVn-abI">
        <img src="https://img.youtube.com/vi/C_uBqVn-abI/maxresdefault.jpg" alt="Palworld Showcase" width="100%"/>
      </a><br>
      <a href="https://www.youtube.com/watch?v=C_uBqVn-abI">▶ Watch on YouTube</a>
    </td>
    <td align="center" width="50%">
      <b>⚡ Community Verified Titles</b><br>
      <i>Final Fantasy XVI, No Man's Sky (Vulkan), and more</i><br><br>
      <i>Rock-solid stability across AMD RDNA 3 and RDNA 4 GPUs.</i>
    </td>
  </tr>
</table>

---

## ⚡ Features

* 🚀 **AMD Neural Rendering Support (`Mochi` / `lmxxf` / `Daniel 0.6.0`):** Experience high-end neural reconstruction natively adapted for AMD RDNA 3 & RDNA 4 GPUs.
* ⚡ **Apex Neural Rendering Frame Generation (`ANR FG` Included):** Automatically installs [Apex Compute's ANR FG](https://github.com/apex-compute/ANR) addon (`FGInput=nvngxfg`, `FGNvngxReplacement=Apex Neural Rendering FG`) to intercept native DLSS-G calls and generate interpolated frames via Vulkan compute alongside AMD-NR visuals.
* 🔮 **Universal DLSS-to-DLSS 5 + FSR-RR Pipeline:** Intercepts DLSS inputs in DirectX 12 titles, tunnels them through FSR 3.1 / FSR Ray Regeneration (`fsr_rr` with `RrBackend=amdnr`), and applies neural reconstruction layers (`DlssNr`) for clean image quality and Ray Reconstruction on AMD GPUs.
* 🧠 **GPU-Aware Auto-Tune:** Detects your AMD RDNA generation at install time and configures optimal `DlssNr` parameters.
* 🔧 **Engine-Specific Tuning:** Includes automatic resource barrier fixes for Unreal Engine 5, Streamline/FrameGen isolation + exposure scanning fixes for Capcom RE Engine, and `OverlayMenu=true` (`Insert`) fixes for GTA V Enhanced.
* 🧹 **Clean 1-Click Uninstaller:** Zero leftover files, 100% reversible via `Uninstall.ps1` using `manifest.json`.

---

## 🏛️ How ED2 Works: "DLSS 5" Visuals + ANR Frame Generation

Envy-Diamond-2 (ED2) orchestrates AMD-NR, OptiScaler, and Apex Neural Rendering FG into one automated setup:

```
[ Game Engine (DX12 / Vulkan / UE5 / RE Engine) ]
               │
               ▼  (Game Menu: Select "DLSS", "DLSS Ray Reconstruction" & "DLSS Frame Gen")
[ OptiScaler + AMD-NR Proxy (dxgi.dll / winmm.dll / version.dll) ]  <── RTX Spoofing
               │
               ├─► [ Visuals: AMD Neural Rendering + Upscaler ]
               │     • Mochi (MochizukiNrRuntime.dll) / lmxxf / Daniel 0.6.0
               │     • FSR 3.1 / FSR Ray Regeneration (fsr_rr, amd_fidelityfx_denoiser_dx12.dll)
               │
               └─► [ FPS: Apex Neural Rendering FG (opt. -SkipAnrFg) ]
                     • OptiScaler\custom\Apex Neural Rendering FG\dlssg\nvngx_dlssg.dll
                     • Vulkan compute frame interpolation (FGInput=nvngxfg)
               │
               ▼
[ High-Fidelity "DLSS 5" Visuals + Neural Frame Generation on AMD Radeon ]
```

1. **Select DLSS + Frame Gen in the game:** Choose **DLSS** (plus **Ray Reconstruction** and **DLSS Frame Generation** where supported).
2. **Visual Neural Enhancement:** OptiScaler routes the game's buffers through AMD-NR (`Mochi`, `lmxxf`, or `Daniel 0.6.0`) and upscales via `fsr_rr` / `ffx` with `SkipReset=true`.
3. **ANR Frame Generation (FPS):** When the game activates native DLSS Frame Generation (`slDLSSGSetOptions`), OptiScaler forwards DLSS-G calls directly to **Apex Neural Rendering FG**, generating smooth interpolated frames on AMD Radeon GPUs (RX 5000 / 6000 / 7000 / 9000 series). *(In titles that keep DLSS-G `OFF` on AMD, ANR FG loads cleanly and stays idle).*

---

## 🛑 The Micro-Stutter Problem

When running DLSS Neural Rendering (DLSS-NR) via OptiScaler on AMD hardware (especially while using heavy background software like OBS Studio), the GPU queue can occasionally bloat. A frame that normally takes 30ms might take 190ms to submit.

When this happens, the AMD proxy (`dlssnr_amd`) initiates a "Host Watchdog" time budget to prevent the game from freezing. The default budget starts at 600ms, but dynamically halves itself on every spike, rapidly plummeting to `87ms`. 

Because the budget drops to 87ms, any frame that takes 190ms to process is instantly aborted. OptiScaler is forced to present the raw, unprocessed 1080p frame to the screen, which users perceive as a jarring 1-fps micro-stutter without anti-aliasing.

Furthermore, if the frame takes too long, OptiScaler falls into internal "booby traps" (at `0x180019442` and `0x180014750`) that completely disable the DLSS Neural Renderer for **1,000 milliseconds**, compounding the stutter.

---

## 🛠️ The Solution: EnvyDynamicPacing.asi (Watchdog v5.0.0)

`EnvyDynamicPacing.asi` is an advanced memory-patching ASI plugin loaded directly by OptiScaler's native plugin loader. Version 1.0.4 completely cures frame pacing breakdowns and raw unscaled frame leaks through surgical assembly interception:

1. **Root-Cause Flag Interception (`0x76D54`):** The AMD neural renderer (`dlssnr_amd`) controls frame acceptance through a master memory flag at RVA `0x76D54` (`>= 0`: Success; `< 0`: Discard & Render Raw). ED2 patches the initialization at `0x1061E` to `0` (Success by default), NOPs the unpatched timeout branch at `0xF0D1`, overrides error writes at `0xF293` to `0`, and continuously clamps `0x76D54` to `0` in live RAM every 50ms.
2. **OptiScaler 16ms Pre-SR Bypass:** OptiScaler contains an internal 16ms deadline on AMD passes. ED2 dynamically hot-patches RVA `0x14585` (`JAE` -> `JMP`), making OptiScaler time-blind so it never aborts frames before sending them to the neural net.
3. **Engine History Reset Suppression (`SkipReset = true`):** When severe GPU load spikes occur (200ms+), game engines (such as RE Engine, Final Fantasy XVI, UE5) falsely assume a scene cut/teleport and issue an explicit `ResetHistory` command to DLSS, which would normally purge the temporal buffer and flash an un-accumulated raw frame. ED2 suppresses these resets, preserving continuous temporal reconstruction through any spike.
4. **Log Sanity & Epilogue Integrity:** Preserves the clean execution jump at RVA `0xF138`, completely preventing false-positive host watchdog timeout log flooding.

**The Result:** 
The renderer is fully immune to frame cancellation. When extreme GPU load or background apps cause a frame to take 200ms+, the engine simply drops FPS gracefully, maintaining 100% reconstructed neural fidelity without flickering raw images, stutters, or crashes!

---

## 📥 Installation

### 1. Easy 1-Click Install (.bat)

1. Download the latest release from the **[Releases](https://github.com/mnector/Envy-Diamond/releases)** tab.
2. Extract the package to a folder on your PC.
3. Double-click **`Install_Game_Admin.bat`** (or drag and drop your game folder directly onto it!):
   * Type, paste, or drag your game's executable folder into the window and press Enter:
     * **RE Engine games** (e.g. *Resident Evil Requiem / BIOHAZARD requiem*):
       ```text
       E:\Steam\steamapps\common\RESIDENT EVIL requiem BIOHAZARD requiem
       ```
     * **DirectX 12 games** (e.g. *FINAL FANTASY XVI*):
       ```text
       E:\Steam\steamapps\common\FINAL FANTASY XVI DEMO
       ```
     * **Grand Theft Auto V Enhanced (Story Mode):**
       ```text
       E:\Steam\steamapps\common\Grand Theft Auto V Enhanced
       ```
       *(Launch with `-nobattleye` for offline Story Mode).*
     * **Unreal Engine games** (e.g. *Palworld*):
       ```text
       C:\Steam\steamapps\common\Palworld\Pal\Binaries\Win64
       ```
   * The installer automatically fetches the latest official AMD-NR release from GitHub, checks for ReShade, configures optimal INI parameters (`SkipReset=true`), and creates an automated backup.

### 2. GUI Window Installer
Double-click `Setup.bat` (or run `.\Setup.GUI.ps1`), click **Browse...**, select the game executable directly (e.g. `re9.exe`), and click **Install**.

### 3. PowerShell CLI
```powershell
# Default install (AMD-NR + Apex Neural Rendering FG included)
.\Setup.Install.ps1 -GameDir "E:\Steam\steamapps\common\YourGame"

# Optional: install AMD-NR without ANR FG
.\Setup.Install.ps1 -GameDir "E:\Steam\steamapps\common\YourGame" -SkipAnrFg
```

---

## 🗑️ Clean Uninstallation (1-Click Restore)

To completely uninstall ED2 and restore all original files:
```powershell
.\Uninstall.ps1 -game "E:\Steam\steamapps\common\YourGame"
```
The uninstaller removes all proxies, runtime libraries, and config files installed by ED2. If original game files were backed up during installation, they are restored with full fidelity.

---

### 🧟 Capcom RE Engine Configuration Notes (Resident Evil Requiem / BIOHAZARD requiem)

When running ED2 with Capcom RE Engine games that integrate NVIDIA Streamline, several strict engine validation checks must be observed.

> [!IMPORTANT]
> **Monolithic REFramework is Required:** Almost all modern RE Engine games require the latest monolithic build of **REFramework** (`dinput8.dll`) to prepare the engine environment and bypass anti-tamper integrity checks.
> * Extract **only** `dinput8.dll` (and `reframework_revision.txt`) into the game folder.
> * **Do NOT extract the VR files** (`openvr_api.dll`, `openxr_loader.dll`) unless playing in VR.
> * **Do NOT enable DLSS/Upscaler inside REFramework's menu:** Let OptiScaler handle the upscaling pipeline; activating REFramework's internal upscaler will cause hook collisions.

1. **In-Game Settings:** In the graphics menu, select **DLSS** (and optionally DLSS Ray Reconstruction). Selecting DLSS routes the frame inputs into OptiScaler, through the neural reconstruction layers, and outputs via the FSR 3.1 tunnel (`Dx12Upscaler=ffx`).
2. **Hotkey Separation:**
   * **REFramework Overlay:** Opens with `Insert` (`VK_INSERT`).
   * **OptiScaler / ED2 Overlay:** Opens with `Home` (`VK_HOME` / `0x24`). This prevents input capture conflicts between both tools.
3. **GPU Spoofing Target (RTX 3090):** RE Engine games use NVIDIA Streamline 2.x. Spoofing an RTX 4090 triggers Streamline to enforce DLSS Frame Generation (`kFeatureDLSS_G`), which requires Ada Lovelace hardware and causes an unhandled exception crash (`0x9fb347e` / missing DLSS-G context). ED2 automatically configures RTX 3090 spoofing to unlock DLSS Super Resolution and Ray Reconstruction safely.
4. **Proxy Selection:** For RE Engine games, installing OptiScaler as `version.dll` provides flawless stability. The installer detects RE Engine automatically and defaults to `version.dll`.

---

### 🚗 Grand Theft Auto V Enhanced, Ray Reconstruction (`fsr_rr`) & ANR FG Notes

1. **Overlay Menu & FrameGen (`OverlayMenu=true`):** AMD-NR R22 Quirks disable the overlay menu and Frame Generation in GTA V Enhanced unless `[Menu] OverlayMenu=true` is explicitly set. `Setup.Install.ps1` now enforces `OverlayMenu=true`, `ShortcutKey=0x2D`, and `MenuKey=0x2D` (`Insert`) automatically.
2. **LocalAppData INI Precedence:** If R22 cannot write to the game folder while running, it saves overlay changes to `%LOCALAPPDATA%\AMDNR\settings\GTA5_Enhanced\OptiScaler.ini`, which takes priority on subsequent launches. Make sure `OverlayMenu = true` stays set there if you edit settings in-game.
3. **DLSS Ray Reconstruction without Daniel 0.8.0 (`fsr_rr`):**
   * Setting `Dx12Upscaler = fsr_rr` (with `[FSR-RR] RrBackend = amdnr`) serves in-game DLSS Ray Reconstruction (`DLSSD`) calls on RDNA 4 via AMD's bundled `amd_fidelityfx_denoiser_dx12.dll` — **no Daniel 0.8.0 (`AMDNR-NeuralHub-080\neuralhub_host.dll`) required**.
   * Keeping `Dx12Upscaler = dlssd` requires Daniel 0.8.0 (`neuralhub_host.dll`), which must match the verified release installed through `AMDNR-Launcher`.
4. **ANR Frame Generation (`apex-compute/ANR`, Included by Default):**
   * Tested alongside AMD-NR R22 (`FG-V.B15` addon; installer pulls the latest `anr-fg-*-addon.zip` release with SHA-256 verification and configures `FGInput=nvngxfg`, `FGNvngxReplacement=Apex Neural Rendering FG`) on **AMD Radeon AI PRO R9700** (RDNA 4) in GTA V Enhanced: ANR FG generates interpolated frames via Vulkan compute once the game activates DLSS Frame Generation (`slDLSSGSetOptions`).
   * In titles where the game itself keeps DLSS-G `OFF` on AMD (e.g., *Palworld*), ANR FG initializes cleanly but remains idle (`Current DLSSG state: OFF`).
5. **Story Mode vs. GTA Online (BattlEye Safety):**
   * **Never** launch GTA Online with `dxgi.dll`, `OptiScaler/`, `dlssnr*`, or any proxy/mod files inside the game directory — BattlEye blocks `dxgi.dll` and using DLL injection online risks an account ban.
   * Launch **Story Mode** with `-nobattleye` (`steam://run/3240220//-nobattleye/`), and keep a clean vanilla game folder (move all mod/backup/log files out to an external folder) whenever you switch back to **GTA Online** with BattlEye enabled.

---

### 🏛️ Universal DX12 Stability (Swapchain Resize Fixes)

Many DirectX 12 games crash when transitioning from pre-rendered intro videos to the main menu because the engine attempts to resize the DXGI swapchain while Frame Generation proxies are active.

ED2 has been made **100% generic for DX12** by configuring the installer to enforce the following swapchain stability fixes out-of-the-box across all titles:
```ini
[FrameGen]
PreserveSwapChain=false
SkipResizeBuffers=false
ModifyBufferState=true
ModifySCIndex=true
```
This guarantees the proxy passes `ResizeBuffers` events seamlessly to the game engine, completely eliminating main menu initialization crashes without requiring manual INI tweaks.

---

## 🙏 Credits, Acknowledgments & Upstream Licenses

Envy-Diamond-2 (ED2) is strictly an automated online installer and configuration wrapper — **huge thanks to all the upstream developers and open-source contributors** whose work makes Neural Rendering and Frame Generation possible on AMD Radeon GPUs. No third-party binaries are bundled in this repository; `Setup.Install.ps1` downloads official packages directly from their authors' GitHub releases at runtime under their respective licenses:

| Project & Author | Role in Stack | License & Notes |
| --- | --- | --- |
| **[Apex Neural Rendering (ANR)](https://github.com/apex-compute/ANR)** by **[Apex Compute](https://apexcompute.com/neural-rendering)** | **ANR FG** (Vulkan compute neural Frame Generation addon) | Official beta addon (`anr-fg-*-addon.zip`) fetched directly from `apex-compute/ANR` with SHA-256 verification (*source code coming soon*; `nr-record` source in repo) |
| **[AMDNR (`AMD-NR---OptiScaler`)](https://github.com/3zwr1/AMD-NR---OptiScaler)** by **3zwr1** | Core AMD Neural Rendering pipeline, Ray Regeneration rules, `c32w`/`fastk2` kernels & OptiScaler R22+ host | **GNU GPL v3** (with additional attribution terms per `AMDNR_NOTICE.txt` §3–4: *AMDNR by 3zwr1*) |
| **[OptiScaler](https://github.com/optiscaler/OptiScaler)** by the **OptiScaler Contributors** | Base upscaler/FrameGen proxy, Streamline/NGX hooks & in-game overlay | **GNU GPL v3** |
| **[DLSS-NR-on-AMD](https://github.com/danielblnc/DLSS-NR-on-AMD)** by **Daniel Blanco (`danielblnc`)** | Original DLSS-NR on AMD runtime (`dlssnr_amd_pass1..3.dll` & NeuralHub) | **All Rights Reserved** — fetched unmodified from official releases with prominent attribution; do not repack |
| **[dlss5-on-amd-9070xt-porting](https://github.com/lmxxf/dlss5-on-amd-9070xt-porting)** by **Kien (`lmxxf`)** | Open-source `lmxxf` neural network port, kernels & runtime | **MIT License** |
| **Mochi** by **mochizuki0323** | `MochizukiNrRuntime.dll` (Mochi 0.0.8.2) & public Mochi 0.0.7 model tool | **MIT License** |
| **Dagherbou (`OptiScaler_DLSSNR`), wilsjo2, Matheus & TheAutomatic (`dlss-5-amd-project`)** | Foundational pre-SR DLSS-NR code, snapshot bookkeeping & `lmxxf` C++ runtime glue | **GNU GPL v3 / MIT License** |
| **[ReShade](https://reshade.me/)** by **crosire**, **RenoDX**, **zgauthier2000 (`cyboman`)** | Coexistence detection, colour composition maths & shader overrides | **BSD-3-Clause** / respective licenses |
| **[HelixSR](https://github.com/lonewolf0622/HelixSR)** (`lonewolf0622`), **[d4r](https://github.com/countervolts/d4r)** (`countervolts`), **AMD FidelityFX SDK**, **Intel XeSS** & **Microsoft DirectX** | Optional ecosystem providers & vendor SDK libraries | HelixSR Freeware / **Apache-2.0** / **MIT** / vendor EULAs |

---

## ⚖️ Disclaimer

> [!CAUTION]
> This project modifies game binaries and proxy DLLs in memory. **Use at your own risk in single-player games only.** Do not use in multiplayer games with anti-cheat software, as it will likely result in an account ban.

> [!TIP]
> **Log Location:** Environment log files are written to the current working directory by default. Use `ENY_LOG_PATH` environment variable to specify a custom location.

> [!TIP]
> **GPU Generation:** The installer detects your AMD GPU generation and optimizes settings accordingly. Full DLSS-NR support requires RDNA 3 or newer.

---

<div align="center">

### ❤️ Support the Project

*If this mod saved your framerate and you love playing with DLSS 5 on AMD hardware, consider buying me a coffee or donating to support ongoing development!*

<br>

<a href="https://paypal.me/mnecstream" target="_blank"><img src="https://www.paypalobjects.com/webstatic/mktg/logo/pp_cc_mark_111x69.jpg" alt="Donate with PayPal" width="120"/></a>

<br><br>

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/mnecstream)

<br>

*¡Muchas gracias por tu apoyo! Cada donación ayuda enormemente a seguir investigando, mejorando el código y testeando nuevos juegos.*

</div>
