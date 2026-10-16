**Title:** Envy-Diamond-2: Unlock DLSS Neural Rendering on Radeon GPUs & Fix OptiScaler Micro-Stutters!

**Body:**

Hey r/radeon community,

I wanted to share a project called **Envy-Diamond-2 (ED2)**. If you've been using or experimenting with OptiScaler to get DLSS Neural Rendering (DLSS-NR) features running on your AMD hardware, you've probably run into some frustrating micro-stuttering issues. ED2 is designed to fix that and unlock the true power of DLSS/OptiScaler features on AMD GPUs.

**The Problem:**
When running DLSS-NR via OptiScaler on AMD cards (especially when multitasking or using heavy software like OBS), the GPU queue can get bloated. The AMD proxy initiates a "Host Watchdog" time budget that dynamically halves itself when there's a spike (down to 87ms). When a frame takes longer than this budget, the frame is aborted, and OptiScaler is forced to present an unprocessed, raw 1080p frame. This feels like a jarring 1-fps micro-stutter without anti-aliasing. Worse, OptiScaler can fall into internal traps that disable DLSS-NR entirely for a full second.

**The Solution (ED2):**
ED2 injects a custom proxy/translation layer. The core of this is **EnvyDynamicPacing.asi**, an ASI plugin that uses memory patching to fix the stutters:
1. **Bypasses OptiScaler's Penalty:** Dynamically rewrites assembly branches to make the 1-second DLSS deactivation penalties unreachable.
2. **Freezes the AMD Proxy Budget:** Modifies the `dlssnr_amd_pass` modules to freeze the time budget at its maximum (600ms).

This means the game engine gracefully yields to the GPU's pace, processes the interpolated frame successfully, and completely eliminates those jarring unprocessed frames and micro-stutters!

**Key Features:**
*   🚀 **AMD Neural Rendering Support:** Natively adapted for AMD architecture via HIP.
*   🧠 **GPU-Aware Auto-Tune:** Detects your RDNA generation at install time for optimal parameters.
*   ⚙️ **Native TDR Configuration:** Automatically configures Windows TDR registry to prevent HIP compute kernel timeouts.
*   🔧 **Unreal Engine 5 Hardened:** Automatic resource barrier fixes to prevent memory access violations/artifacting in UE games.

**Check it out:**
*   **GitHub Repository:** [https://github.com/mnector/ED2](https://github.com/mnector/ED2)
*   **Video Showcase (Palworld):** [https://youtu.be/9OoNgYDe6Uo](https://youtu.be/9OoNgYDe6Uo)

I'd love for you guys to test it out (single-player only!) and let me know what you think. If you have any feedback or run into issues, feel free to drop a comment or open an issue on GitHub.

Let's show some love for Radeon! 🔴💎
