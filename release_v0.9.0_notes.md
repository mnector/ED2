# 💎 Envy-Diamond-2 v0.9.0 (Absolute Zero Stutter Edition)

This milestone release introduces the **Digital Bottomless Pit** architecture, completely neutralizing the hardcoded 1-second dlssnr deactivation penalties inside OptiScaler's dxgi.dll. 

### ✨ What's New
- **The Immortal Watchdog (Memory Injector):** EnvyDynamicPacing.asi dynamically locates and patches OptiScaler's ecovery pending and etry in 1s branches in memory, making the 1000ms penalty mathematically unreachable.
- **Budget Freezer:** Prevents the AMD Neural Renderer proxy from dynamically halving its time budget under heavy load (like OBS recording). By freezing the host watchdog budget at 600ms, the game engine can smoothly yield during capture spikes instead of instantly aborting and dropping frames.
- **No TLB-Shootdown Stutters:** Memory patches are applied natively to the .text section during initialization without continuous VirtualProtect polling, guaranteeing zero overhead to your CPU cores.

### 📥 Installation
1. Extract Envy-Diamond-2-v0.9.0.zip.
2. Place EnvyDynamicPacing.asi inside your game's OptiScaler/plugins/ folder.
3. Ensure LoadAsiPlugins=true is set in OptiScaler.ini.
