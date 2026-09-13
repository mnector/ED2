# Envy-Diamond v2 — AMD Pre-SR Neural Rendering

## What Changed in v2

The external Dynamic Pacing Daemon (`EnvyDynamicPacing.ps1`, `Launch-Envy.bat`, `Launch-Envy-variable.bat`) has been **removed entirely**. It was a runtime workaround that masked the real issue by throttling FPS when AMD HIP timeouts were detected in logs.

### Root Cause Fix: Windows TDR Configuration

The actual problem was the Windows TDR (Timeout Detection and Recovery) default timeout of **2 seconds** — far too short for AMD HIP neural-rendering compute kernels competing with game rendering, upscaling, and frame generation for GPU time.

Setup now configures:
- `TdrDelay = 8` (from 2s default) — gives HIP kernels time to complete
- `TdrDdiDelay = 10` (from 5s default) — margin for DDI callbacks
- `TdrLimitCount = 10` (from 5 default) — more tolerance before system crash
- `TdrLimitTime = 120` (from 60s default) — wider observation window

Previous TDR values are backed up to `tdr_backup.json` in the game's backup folder.

### GPU-Aware DlssNr Auto-Tune

Setup detects the RDNA generation of the installed AMD GPU and configures `[DlssNr]` parameters accordingly:
- **RDNA 4**: Full NR enabled (ModelScale=1, NeuralLighting=0.5)
- **RDNA 3**: Light NR (ModelScale=1, NeuralLighting=0.3)
- **RDNA 2 or unknown**: NR disabled (insufficient compute throughput)

### Frame Pace Tuning

FSRFG parameters are set to conservative values:
- `FPTSafetyMarginInMs=0.75` (more GPU headroom during HIP execution)
- `FPTVarianceFactor=0.3` (aggressive FPS recovery)
- `FPTHybridSpin=true` (reduces CPU-GPU contention)

### Resource Barriers

UE5 resource barriers are enabled by default:
- `ColorResourceBarrier=4` (D3D12_RESOURCE_STATE_RENDER_TARGET)
- `MotionVectorResourceBarrier=8` (D3D12_RESOURCE_STATE_UNORDERED_ACCESS)

### FramerateLimit

`FramerateLimit` is set to `0.0` (disabled). The old daemon's static 30fps cap has been removed — FPS are no longer artificially limited because the TDR fix addresses the root cause.

---

HIP worker publication still follows the actual D3D12 ExecuteCommandLists call. Queue binding remains before submission. Multipass ordering, completion fences and timeout protections are retained.

For Spider-Man on AMD, use `-forceReflexMarkers` in Steam launch options to enable the documented Streamline path while retaining `Dxgi=false` for ray-tracing compatibility.

**Restart your PC after the first install for TDR changes to take full effect.**
