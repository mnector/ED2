<div align="center">

# 💎 Envy-Diamond-2 💎

**Advanced Neural Rendering & Frame Generation Translation Layer for AMD GPUs**

[![Release](https://img.shields.io/github/v/release/mnector/Envy-Diamond?style=for-the-badge&color=blue)](https://github.com/mnector/Envy-Diamond/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?style=for-the-badge)]()
[![GPU](https://img.shields.io/badge/GPU-AMD%20Radeon-red?style=for-the-badge)]()

Envy-Diamond-2 unlocks the true power of DLSS and OptiScaler features on AMD hardware, injecting a custom proxy to translate calls and deliver massive framerate uplifts!

</div>

---

## 🎥 See it in Action

<table>
  <tr>
    <td align="center" width="50%">
      <b>🧟 Resident Evil Requiem (BIOHAZARD requiem)</b><br>
      <i>DLSS 5 Neural Tunneling, Multi-Pass Inference & RE Engine Stability</i><br><br>
      <a href="https://www.youtube.com/watch?v=Bzbo73zTuVA">
        <img src="https://img.youtube.com/vi/Bzbo73zTuVA/maxresdefault.jpg" alt="Resident Evil Requiem Showcase" width="100%"/>
      </a><br>
      <a href="https://www.youtube.com/watch?v=Bzbo73zTuVA">▶ Watch on YouTube</a>
    </td>
    <td align="center" width="50%">
      <b>🐾 Palworld</b><br>
      <i>Zero Stutters with The Digital Bottomless Pit Watchdog</i><br><br>
      <a href="https://www.youtube.com/watch?v=C_uBqVn-abI">
        <img src="https://img.youtube.com/vi/C_uBqVn-abI/maxresdefault.jpg" alt="Palworld Showcase" width="100%"/>
      </a><br>
      <a href="https://www.youtube.com/watch?v=C_uBqVn-abI">▶ Watch on YouTube</a>
    </td>
  </tr>
</table>

---

## ⚡ Features

* 🚀 **AMD Neural Rendering Support:** Experience high-end upscaling paths natively adapted for AMD architecture via HIP.
* 🔮 **Universal DLSS-to-DLSS 5 Pipeline:** Intercepts DLSS inputs in any DirectX 12 game, tunnels them through FSR 3.1 (`ffx`), and processes them through neural reconstruction layers (`DlssNr` + `AmdLook`) to output a next-generation "DLSS 5" appearance on AMD RDNA GPUs.
* 🛡️ **The Digital Bottomless Pit (v1.0.0):** A revolutionary memory-patching ASI plugin that perfectly prevents frame-drops and DLSS deactivations by freezing the internal `dlssnr_amd` time budget.
* ⚙️ **Native TDR Configuration:** Setup automatically configures Windows TDR registry to prevent AMD HIP compute kernel timeouts during heavy neural rendering passes.
* 🧠 **GPU-Aware Auto-Tune:** Detects your RDNA generation at install time and configures optimal DlssNr parameters.
* 🔧 **Engine-Specific Tuning:** Includes automatic resource barrier fixes for Unreal Engine 5 and Streamline/FrameGen isolation + exposure scanning fixes for Capcom RE Engine.

---

## 🏛️ How ED2 Works: The "DLSS 5" Neural Tunnel

Envy-Diamond-2 (ED2) is a generic translation architecture designed to achieve neural rendering quality on AMD hardware:

```
[ Game Engine (UE5 / RE Engine) ]
               │
               ▼  (Game Menu: Select "DLSS" / "DLSS Ray Reconstruction")
[ OptiScaler Proxy (dxgi.dll) ]  <── RTX Spoofing (RTX 3090 / 4090)
               │
               ├─► [ AMD Neural Reconstruction Layer (DlssNr / AmdLook) ]
               │     • dlssnr_amd_pass1..3.dll
               │     • dlssnr_on_amd_weights.bin
               │     • EnvyDynamicPacing.asi (Watchdog budget freezer)
               │
               ▼
[ FSR 3.1 Super-Resolution Tunnel (Dx12Upscaler=ffx) ]
               │
               ▼
[ High-Fidelity "DLSS 5" Output on AMD RDNA 3 / 4 ]
```

1. **Select DLSS in the game:** The user selects **DLSS** in the game's graphics settings (spoofed adapter makes the game expose DLSS).
2. **Interception:** OptiScaler intercepts the DLSS call and feeds the motion vectors, depth, and color buffers into the pre-SR pipeline.
3. **Neural Enhancement:** The AMD HIP neural passes apply model weights (`dlssnr_on_amd_weights.bin`) and spatial reconstruction (`AmdLook`).
4. **FSR Tunnel:** The enhanced active-resolution signal is resolved through AMD FidelityFX (`ffx`), yielding a reconstructed "DLSS 5" image with maximum stability and fidelity.

---

## 🛑 The Micro-Stutter Problem

When running DLSS Neural Rendering (DLSS-NR) via OptiScaler on AMD hardware (especially while using heavy software like OBS Studio), the GPU queue can occasionally bloat. A frame that normally takes 30ms might take 190ms to submit.

When this happens, the AMD proxy (`dlssnr_amd`) initiates a "Host Watchdog" time budget to prevent the game from freezing. The default budget starts at 600ms, but dynamically halves itself on every spike, rapidly plummeting to `87ms`. 

Because the budget drops to 87ms, any frame that takes 190ms to process is instantly aborted. OptiScaler is forced to present the raw, unprocessed 1080p frame to the screen, which users perceive as a jarring 1-fps micro-stutter without anti-aliasing.

Furthermore, if the frame takes too long, OptiScaler's `dxgi.dll` falls into internal "booby traps" (at `0x180019442` and `0x180014750`) that completely disable the DLSS Neural Renderer for **1,000 milliseconds**, compounding the stutter.

---

## 🛠️ The Solution: EnvyDynamicPacing.asi

`EnvyDynamicPacing.asi` is a custom ASI plugin loaded directly by OptiScaler that solves both issues via surgical memory patching:

1. **OptiScaler 1-Second Penalty Bypass:** It locates the `dxgi.dll` module and dynamically rewrites the assembly branches (`je` -> `jmp`) for the two timeout penalties, making them mathematically unreachable.
2. **AMD Proxy Budget Freezer & Iteration Cap Unlocked:** It scans `dlssnr_amd_pass*.dll` modules to find the exact `xchg` instruction that dynamically lowers the time budget, and completely NOPs it out (replacing it with `0x90`). 

**The Result:** 
The time budget is permanently frozen at its maximum value (600ms). When OBS spikes the game to 190ms, the proxy simply waits patiently. The game engine gracefully yields (relentiza) to the GPU's pace, processes the interpolated frame successfully, and presents it. Unprocessed raw frames are completely eliminated, achieving perfect frame pacing under heavy load without catastrophic 6-second TLB-shootdown freezes!

---

## 📥 Installation

### Quick Installation (Recommended)

1. Go to the **[Releases](https://github.com/mnector/Envy-Diamond/releases)** tab and download the latest `Envy-Diamond-2-v1.0.2.zip`.
2. Extract the package contents to a folder on your PC (e.g., `C:\Tools\ED2`).
3. **Configure Windows TDR (One-Click):**
   Double-click **`Fix_TDR_Admin.bat`**. 
   * It will automatically request administrator permissions via UAC.
   * It configures safe 60-second timeout limits (`TdrDelay` = 60s, `TdrDdiDelay` = 60s) to prevent Windows from terminating the GPU driver during initial neural shader compilation and heavy rendering spikes.
   * **Restart your PC** after running it to ensure Windows applies the registry changes.

4. **Install into your Game (Simple 1-Click .bat):**
   Double-click **`Install_Game_Admin.bat`** (or drag and drop your game folder directly onto it!):
   * It will ask for administrator permissions via UAC.
   * Type, paste, or drag your game's executable folder into the window and press Enter:
     * **RE Engine games** (e.g. *Resident Evil Requiem / BIOHAZARD requiem*):
       ```text
       E:\Steam\steamapps\common\RESIDENT EVIL requiem BIOHAZARD requiem
       ```
     * **Unreal Engine games** (e.g. *Palworld*):
       ```text
       C:\Steam\steamapps\common\Palworld\Pal\Binaries\Win64
       ```
   * The installer will automatically tune `OptiScaler.ini`, deploy the appropriate proxy (`version.dll` for RE Engine, `dxgi.dll` for UE5), and install `EnvyDynamicPacing.asi`!

5. **Advanced / Alternative Installation Options:**
   * **PowerShell CLI:**
     ```powershell
     .\Setup.Install.ps1 -GameDir "<Path_To_Executable_Folder>"
     ```
   * **GUI Window:** Double-click `Setup.bat` (or execute `.\Setup.GUI.ps1`), click **Browse...**, select the game executable directly (e.g. `re9.exe`), and click **Install**.

6. Verify your installation at any time:
   ```powershell
   .\Setup.Validate.ps1 -GameDir "E:\Steam\steamapps\common\RESIDENT EVIL requiem BIOHAZARD requiem"
   ```

### ⚡ Easy 1-Click Tools Reference

| Script | Purpose |
| :--- | :--- |
| **`Fix_TDR_Admin.bat`** | Double-click to auto-elevate and configure safe 60s Windows TDR timeout limits for AMD GPUs. |
| **`Install_Game_Admin.bat`** | Double-click to auto-elevate and install ED2 by simply entering/dragging your game folder path. |
| **`Setup.bat`** | Graphical user interface (GUI) installer for picking `.exe` files via Windows Explorer. |
| **`Setup.Validate.ps1`** | Validates files, proxies, ASI plugins, and registry settings for complete peace of mind. |

---

### 🧟 Capcom RE Engine Configuration Notes (Resident Evil Requiem / BIOHAZARD requiem)

When running ED2 with Capcom RE Engine games that integrate NVIDIA Streamline, several strict engine validation checks must be bypassed.

> [!IMPORTANT]
> **Monolithic REFramework is Required:** Almost all modern RE Engine games require the latest monolithic build of **REFramework** (`dinput8.dll`) to prepare the engine environment and bypass anti-tamper integrity checks.
> * Extract **only** `dinput8.dll` (and `reframework_revision.txt`) into the game folder.
> * **Do NOT extract the VR files** (`openvr_api.dll`, `openxr_loader.dll`) unless you are playing in VR, as they destabilize the engine and disable temporal anti-aliasing.
> * **Do NOT enable DLSS/Upscaler inside REFramework's menu:** Let OptiScaler handle the upscaling pipeline; activating REFramework's internal upscaler will cause hook collisions.

1. **In-Game Settings:** In the graphics menu, select **DLSS** (and optionally DLSS Ray Reconstruction). Selecting DLSS routes the frame inputs into OptiScaler, through the neural reconstruction layers, and outputs via the FSR 3.1 tunnel (`Dx12Upscaler=ffx`).
2. **Hotkey Separation:**
   * **REFramework Overlay:** Opens with `Insert` (`VK_INSERT`).
   * **OptiScaler / ED2 Overlay:** Opens with `Home` (`VK_HOME` / `0x24`). This prevents input capture conflicts between both tools.
3. **GPU Spoofing Target (RTX 3090):** RE Engine games use NVIDIA Streamline 2.x. Spoofing an RTX 4090 triggers Streamline to enforce DLSS Frame Generation (`kFeatureDLSS_G`), which requires Ada Lovelace hardware and causes an unhandled exception crash (`0x9fb347e` / missing DLSS-G context). ED2 automatically configures:
   ```ini
   [Spoofing]
   SpoofedVendorId=0x10de
   SpoofedDeviceId=0x2204
   SpoofedGPUName=NVIDIA GeForce RTX 3090
   ```
   This fully unlocks DLSS Super Resolution and DLSS Ray Reconstruction in the game menu without triggering the DLSS-G crash.
4. **Frame Generation Isolation:** Keep `External=true` and `Enabled=false` under `[FrameGen]` so OptiScaler leaves swapchain management to the engine:
   ```ini
   [FrameGen]
   External=true
   Enabled=false
   ```
5. **Exposure Scanner, Signatures, Overlays & Pre-SR Pipeline:** 
   - Strict DX12 engines (such as RE Engine) manage their internal command lists and texture states with rigid validation. Running compute shaders prior to super resolution (`RunBeforeSR=true`) triggers memory state collisions (`0x9fb347e`). ED2 configures `RunBeforeSR=false` and `ScanExposure=false`.
   - Steam and Epic Games overlays severely conflict with OptiScaler's DXGI integration in RE Engine games. ED2 configures `DisableOverlays=true`.
   - Monolithic REFramework dynamically manages DX12 root signatures; forcing OptiScaler to restore them triggers `0x887a0006` device hung errors. Both are set to `false`:
   ```ini
   [DlssNr]
   ScanExposure=false
   Enabled=false
   RunBeforeSR=false
   
   [AmdLook]
   Enabled=true

   [Hotfix]
   RestoreComputeSignature=false
   RestoreGraphicSignature=false
   DisableOverlays=true

   [Menu]
   OverlayMenu=true
   ShortcutKey=0x24
   MenuKey=0x24
   ```
6. **Proxy Selection (`version.dll` vs `dxgi.dll`):**
   - For RE Engine games where Steam overlay and engine video playback hook DXGI early, installing OptiScaler as `version.dll` provides flawless stability. The installer detects RE Engine automatically and defaults to `version.dll`.
   - `EnvyDynamicPacing.asi` automatically detects OptiScaler under either `version.dll` or `dxgi.dll`, applying the Digital Bottomless Pit watchdog patches to freeze proxy time budgets and eliminate presentation penalties.
7. **No Rogue Proxy Files:** Never copy or rename `OptiScaler.dll` to `nvngx.dll`. OptiScaler functions strictly as a system proxy (`version.dll` or `dxgi.dll`). Placing a fake `nvngx.dll` in the game root breaks Streamline's NGX context initialization.

---

### 🏛️ Universal DX12 Stability (Swapchain Resize Fixes)

Many DirectX 12 games crash when transitioning from pre-rendered intro videos (often fixed resolution/refresh rates) to the main menu (full 3D render target resolution) because the game engine attempts to resize the DXGI swapchain while Frame Generation proxies are active.

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

## ⚖️ Disclaimer

> [!CAUTION]
> This project modifies game binaries and proxy DLLs in memory. **Use at your own risk in single-player games only.** Do not use in multiplayer games with anti-cheat software, as it will likely result in an account ban.

> [!TIP]
> **Log Location:** Environment log files are written to the current working directory by default. Use `ENY_LOG_PATH` environment variable to specify a custom location.

> [!TIP]
> **GPU Generation:** The installer detects your AMD GPU generation and optimizes settings accordingly. Full DLSS-NR support requires RDNA 3 or newer.

