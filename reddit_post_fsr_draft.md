**Title:** [Tool] FSR-NG-Scaling: Add DLSS-NR & XeSS to ANY Game on Radeon GPUs (Zero Process Injection!)

**Body:**

Hey r/radeon,

I want to share another massive project I've been working on called **FSR-NG-Scaling**.

While my previous project (Envy-Diamond-2) fixed OptiScaler micro-stutters, FSR-NG-Scaling is a completely **standalone, ultra-low latency real-time neural upscaler**. It allows you to bring native DLSS Neural Rendering (DLSS-NR), Intel XeSS, and AMD FidelityFX upscaling to **any window or game** on your AMD Radeon GPU.

The best part? It operates with **Zero Process Injection**.

**How it works:**
FSR-NG-Scaling doesn't touch your game's memory or inject any DLLs. It runs as a completely external overlay that captures frames directly from the desktop/GPU surface. It integrates a parallel ONNX Runtime to dynamically hallucinate missing depth maps for native upscaling logic. This means it is **100% anti-cheat safe**.

Because it's powered by the **Envy-Diamond-2 (ED2)** engine, you still get all the stutter-free benefits:
*   **The Digital Bottomless Pit (`EnvyDynamicPacing.asi`):** Freezes AMD proxy time budgets to prevent frame drops and bypasses OptiScaler penalties during heavy GPU loads.

**Key Features:**
*   🛡️ **100% External & Anti-Cheat Safe:** No hooking into game binaries.
*   🧠 **Real-Time AI Depth Estimation:** Generates depth maps on the fly so games without native upscaling support can still use DLSS-NR/FSR.
*   ⚡ **Absolute Zero-Stutter Frame Pacing:** Thanks to the built-in ED2 engine.
*   🖱️ **Intelligent Dual-Mode Input:** Press `Ctrl + Alt + S` to pass inputs straight to the game, or `Ctrl + Alt + M` to interact with the GUI.
*   📐 **Adaptive DPI:** Seamlessly handles Windows 11 display scaling and multi-monitor setups.
*   🏎️ **Ultra-Low Latency:** Uses DXGI Flip-Discard swapchain synced with VSync.

**Try it out:**
*   **GitHub Repository:** [https://github.com/mnector/FSR-NG-Scaling](https://github.com/mnector/FSR-NG-Scaling)
*   **Download:** Check the Releases tab for the pre-built `v1.0.3` version.

If you have games where you couldn't mod in FSR/DLSS before, this is the tool for you. Run it, set your game to Borderless/Windowed, and press `Ctrl + Alt + S`.

Let me know how it performs on your Radeon rigs! All feedback and testing are heavily appreciated. 🔴💎