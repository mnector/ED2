<div align="center">

# 💎 Envy-Diamond (Absolute Zero Stutter Edition) 💎

**Advanced Neural Rendering & Frame Generation Translation Layer for AMD GPUs**

[![Release](https://img.shields.io/github/v/release/mnector/Envy-Diamond?style=for-the-badge&color=blue)](https://github.com/mnector/Envy-Diamond/releases)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?style=for-the-badge)]()
[![GPU](https://img.shields.io/badge/GPU-AMD%20Radeon-red?style=for-the-badge)]()

Envy-Diamond unlocks the true power of DLSS and OptiScaler features on AMD hardware, injecting a custom proxy to translate calls and deliver massive framerate uplifts!

</div>

---

## ⚡ Features

* 🚀 **AMD Neural Rendering Support:** Experience high-end upscaling paths natively adapted for AMD architecture via HIP.
* 🛡️ **The Digital Bottomless Pit (v15.0):** A revolutionary memory-patching ASI plugin that perfectly prevents frame-drops and DLSS deactivations by freezing the internal `dlssnr_amd` time budget.
* ⚙️ **Native TDR Configuration:** Setup automatically configures Windows TDR registry to prevent AMD HIP compute kernel timeouts during heavy neural rendering passes.
* 🧠 **GPU-Aware Auto-Tune:** Detects your RDNA generation at install time and configures optimal DlssNr parameters.
* 🔧 **Unreal Engine 5 Hardened:** Includes automatic resource barrier fixes to prevent memory access violations and colorful artifacting in UE games.

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
2. **AMD Proxy Budget Freezer:** It scans `dlssnr_amd_pass*.dll` modules to find the exact `xchg` instruction that dynamically lowers the time budget, and completely NOPs it out (replacing it with `0x90`). 

**The Result:** 
The time budget is permanently frozen at its maximum value (600ms). When OBS spikes the game to 190ms, the proxy simply waits patiently. The game engine gracefully yields (relentiza) to the GPU's pace, processes the interpolated frame successfully, and presents it. Unprocessed raw frames are completely eliminated, achieving perfect frame pacing under heavy load without catastrophic 6-second TLB-shootdown freezes!

---

## 📥 Installation

1. Go to the **[Releases](https://github.com/mnector/Envy-Diamond/releases)** tab and download the latest `Envy-Diamond-Release.zip`.
2. Extract the contents.
3. Place `EnvyDynamicPacing.asi` into your game's `OptiScaler/plugins/` directory (e.g. `Palworld\Pal\Binaries\Win64\OptiScaler\plugins\`).
4. Ensure your `OptiScaler.ini` has `LoadAsiPlugins=true` enabled.

---

## ⚖️ Disclaimer

> [!CAUTION]
> This project modifies game binaries and proxy DLLs in memory. **Use at your own risk in single-player games only.** Do not use in multiplayer games with anti-cheat software, as it will likely result in an account ban.
