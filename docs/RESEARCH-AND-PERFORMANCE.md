# Rendering and performance research

Research snapshot: 25 November 2026. Public fork results are single-machine observations, not forecasts for another GPU.

## What the user's captures and logs show

The first DexNom Ultra v0.6 HUD capture showed approximately:
- 0.7 FPS and 1,437.9 ms/frame
- 3,577 draws/frame
- 3,455 dropped draws/frame without a ready host pipeline
- GPU wait 408.8 ms, CPU preparation 555.0 ms, copy-back 451.6 ms
- 3,035 MB process RAM

The later runtime log briefly showed 29-30 FPS while only 6-13 draws were present. As scene work accumulated, frame samples fell as low as 0.2-1.1 FPS. The texture queue grew above 18,000 entries; dropped draws reached 6,304; buffer views were refused; and the local-memory counter approached or exceeded its displayed budget. At one point the log attributed hundreds of milliseconds to CPU preparation and copy-back. Timing categories can overlap and must not be added as exclusive slices.

The later indoor screenshot shows bright ceiling fixtures but very dark surrounding surfaces, along with incomplete character/material detail. This is compatible with the known state of the world renderer: missing shader pipelines and non-working ray-traced indirect lighting can produce missing materials and dark interiors. It is not evidence that increasing desktop brightness or display resolution will fix the renderer.

The code defines a host pipeline as unavailable when one of its shaders does not translate, the host driver refuses the pipeline, or the pipeline is still being made. The dropped count aggregates these causes. It is evidence of major renderer coverage/creation problems, but the HUD number alone cannot identify which shader or driver failure dominates. The matching detailed runtime log is needed.

The v0.6 UltraVisual1080 profile enables material-demand sampling plus early/bake texture work (24 ms / 2500 ms). The source changelog itself warns this may lengthen loading or lower FPS. UltraSafe1080 disables those two experiments and is a better controlled baseline. Neither repairs missing translated shaders.

## Public projects reviewed

### Marvisak/VIctory

Base runtime, D3D12 backend and shader translator:
https://github.com/Marvisak/VIctory

### fxceless/victory-fork

README snapshot dated 25 November 2026 reports 8-10 FPS in the first rooms on one Windows 11 PC with an RTX 4070 12 GB and 32 GB RAM. It documents fixes for meshlet culling, descriptors, lighting data read-back, fog, shadow masks, hair, blend-shape skinning, fire and material shaders. Its first room renders characters, textures and lamps, but shadowed areas remain black because ray-traced bounce light and ray-traced lamp/sun shadows are not working. These results are not measured on an AMD RX 7600:
https://github.com/fxceless/victory-fork

### Belobug/VIctory-Belobug-AMD

The 25 November 2026 README reports 5-8 FPS on one RX 9070 XT 16 GB, Ryzen 7 9800X3D and 64 GB RAM. The world renders textures, people, vehicles, vegetation, water and sky on that machine. Its ambient-light system is an approximation that follows the sky; the game's ray-traced indirect light still does not run. The same README reports about 22 GB of system RAM use and more video memory than a 16 GB card has. These measurements are far above the user's RX 7600 8 GB / 16 GB system configuration and do not predict performance on it:
https://github.com/Belobug/VIctory-Belobug-AMD

A separate open Windows 10 issue reports an RX 7600 8 GB crash at frame 0 after root signatures with flag 0xc01 were refused by the host driver. It is one report on a specific build and does not prove every configuration fails, but it is a directly relevant compatibility warning:
https://github.com/Belobug/VIctory-Belobug-AMD/issues/168

An additional Linux/RADV report on an RX 7600 XT 8 GB describes a black world and a host-wide freeze with this fork's memory footprint. That platform differs from the user's Windows setup, so it is only a further low-memory warning:
https://github.com/Belobug/VIctory-Belobug-AMD/issues/6

Reviewed AMD experiment commit: 4f62c2a5e27e7beebf3e8d68f77898e43dc7b77c.

### AntoninMichelq/VIctory-forkAMD — closest RX 7600 match

This fork's README and HANDOFF document a Windows test on an AMD RX 7600 8 GB with 32 GB physical RAM and a 32 GB page file. Its Peau3 build (`jouer/peau3`, commit `b74ac64da2e289cc632980cf8e508c2d1ba909ac`) measured about 6.2-6.5 FPS in the prison scene over a 10-minute run, around 21 GB of memory, and rendered buildings, cells, characters, hair, skin and sky. The measured configuration rendered internally at 1080p and used PC FidelityFX to upscale to the fixed 4K output.

The fork's HANDOFF still reports intermittent chrome/black patches on clothing, skin and posters, plus late texture arrival. Its `fix/partly-clamp` branch attempts to stop partly mapped texture mips from sampling zeros, but the HANDOFF explicitly says that branch had not yet passed a Windows build or a game run. It is not included in Alligator's tested Peau3 launcher.

Alligator now offers an isolated test of the measured commit. The script keeps a separate engine checkout, release build, shader cache, save/data folder and run log. It requires the PC FidelityFX SDK DLL for the measured 1080p-to-4K path. This is the strongest directly relevant public test found for an RX 7600, but 16 GB of system RAM is below the measured 32 GB configuration; the test may page heavily or fail.

Sources:
- https://github.com/AntoninMichelq/VIctory-forkAMD
- https://github.com/AntoninMichelq/VIctory-forkAMD/blob/main/HANDOFF.md
- https://github.com/AntoninMichelq/VIctory-forkAMD/commit/b74ac64da2e289cc632980cf8e508c2d1ba909ac
### WillyboPeep/victory-all-forks

This is explicitly a test merge of upstream and community forks, not an original implementation. Its documentation lists fixes relevant to the reported defects: meshlet culling, descriptor exhaustion, GPU-written light readback, fog, shadow masks, hair, blend-shape skinning, fire and material shaders. It reports a 5.7 FPS result in one matched view on an RTX 4090 24 GB after selected changes; other test runs are lower. It still lists black shadows and incomplete ray tracing:
https://github.com/WillyboPeep/victory-all-forks
https://github.com/WillyboPeep/victory-all-forks/blob/main/ALL-FORKS.md

### XCL

XCL is a separate Xbox compatibility project with a different renderer/translator and GPL-2.0-only licensing. Its code is not a drop-in source for the GPL-3.0-or-later VIctory-derived engine. It is a reference for ideas only unless license compatibility is established:
https://github.com/ivall/xcl

## Practical plan for RX 7600 8 GB

1. Preserve the known-working v0.6 runtime and its shader cache.
2. Use the isolated Peau3 RX 7600 test as the primary comparison: it is pinned to the measured `b74ac64` commit, uses a separate build/cache/data directory and has a reported 6.2-6.5 FPS result on the same GPU model. Its 32 GB RAM / 32 GB page-file setup is materially larger than a 16 GB RAM PC.
3. Keep the Belobug AMD fork as a separate research comparison, not the first recommended test: its measured machine is much stronger and it has a specific RX 7600 Windows crash report.
4. Analyze the Peau3 log for late texture streaming and black/chrome artifacts. The untested `fix/partly-clamp` change is a candidate only after a Windows build and a matching scene test.
5. Inspect current DexNom logs for `Dropped ... without a host pipeline: <reason>` and buffer-view refusals.
6. Benchmark one change at a time. The goal is to reduce missing host pipelines and resource/copy pressure without trading correct character/material output for FPS.

Do not import memory settings tuned for 12/16/24 GB GPUs into an 8 GB RX 7600. Do not enable ray tracing on the AMD test fork: its own README reports device-removal/stability concerns. Avoid registry/TDR changes and broad cache deletion.

Alligator is only the launcher, configuration and diagnostics workspace. The actual rendering corrections must be implemented and validated in the external VIctory/DexNom renderer source; changing Alligator documentation or profiles alone cannot fix skin, eye, hair, texture or lighting shaders.
