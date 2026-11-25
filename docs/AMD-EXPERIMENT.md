# Experimental AMD fork test

This is an isolated comparison build, not an update to the stable DexNom Ultra v0.6 runtime.

## Source

- Repository: https://github.com/Belobug/VIctory-Belobug-AMD
- Pinned commit: `4f62c2a5e27e7beebf3e8d68f77898e43dc7b77c`
- License: GPL-3.0-or-later (see the fork's LICENSE and attribution in its README).

The commit was selected because its 25 November 2026 README describes AMD-specific fixes for helper-pixel/quad reads (including skin edge artifacts), blend-shape skinning, hair/material shaders, depth/shadow handling, and an ambient-light approximation that follows the sky. The approximation is not full ray-traced global illumination.

## Run

From an Alligator checkout on Windows PowerShell 5.1:

```powershell
.\Alligator.ps1 -Action TestAMD
```

Optional separate hair test:

```powershell
.\Alligator.ps1 -Action TestAMD -EnableHairExperiment
```

The script:
- clones the public fork to `%LOCALAPPDATA%\Alligator\engines\VIctory-Belobug-AMD`;
- checks out the reviewed commit instead of tracking moving `main`;
- uses the fork's pinned Rust toolchain and documented diagnostics build;
- stores its own cache and data under `%LOCALAPPDATA%\Alligator\data\VIctory-Belobug-AMD`;
- does not overwrite DexNom Ultra v0.6 binaries, caches or saves.

The optional hair flag maps to the fork's documented `VICTORY_HAIR=1`. It is not enabled by default because the fork still lists shader translation failures and experimental areas.

## Hardware caution

The fork README reports about 5–8 FPS on one RX 9070 XT 16 GB system with a Ryzen 7 9800X3D and 64 GB RAM. It also reports approximately 22 GB of RAM use and more video-memory demand than a 16 GB card budget in some sessions. These numbers do not predict performance on an RX 7600 8 GB with 16 GB system RAM. The script asks for explicit confirmation before compiling/running. Keep the initial comparison short and monitor RAM, VRAM, missing pipelines and device-removal events.

Do not enable the fork's experimental ray-tracing path for this test: its README reports device removal during ray-enabled sessions.
