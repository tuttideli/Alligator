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

### WillyboPeep/victory-all-forks

This is explicitly a test merge of upstream and community forks, not an original implementation. Its documentation lists fixes relevant to the reported defects: meshlet culling, descriptor exhaustion, GPU-written light readback, fog, shadow masks, hair, blend-shape skinning, fire and material shaders. It reports a 5.7 FPS result in one matched view on an RTX 4090 24 GB after selected changes; other test runs are lower. It still lists black shadows and incomplete ray tracing:
https://github.com/WillyboPeep/victory-all-forks
https://github.com/WillyboPeep/victory-all-forks/blob/main/ALL-FORKS.md

### XCL

XCL is a separate Xbox compatibility project with a different renderer/translator and GPL-2.0-only licensing. Its code is not a drop-in source for the GPL-3.0-or-later VIctory-derived engine. It is a reference for ideas only unless license compatibility is established:
https://github.com/ivall/xcl

## Practical plan for RX 7600 8 GB

1. Preserve the known-working v0.6 runtime and its shader cache.
2. Run Start-Baseline-Diagnostic.ps1 to capture a raw-log Baseline test. Compare it with UltraSafe1080 under the same save, camera and scene.
3. Do not treat the AMD fork as an FPS upgrade for this PC yet. Its measured system is substantially larger, its README still reports 5-8 FPS, and an RX 7600 Windows crash has been reported. Keep the test isolated and defer it until the reported root-signature issue and memory needs are understood.
4. Inspect Dropped ... without a host pipeline: <reason> lines and buffer-view refusals from the per-run log.
5. Identify specific missing shader/material/light paths in the renderer source. Port only a narrow fix with author attribution, compatible GPL-3.0-or-later licensing, a clean build and a binary rollback.
6. Benchmark one change at a time. The goal is to reduce missing host pipelines and resource/copy pressure before making claims about FPS.

Do not import memory settings tuned for 12/16/24 GB GPUs into an 8 GB RX 7600. Do not enable ray tracing on the AMD test fork: its own README reports device-removal/stability concerns. Avoid registry/TDR changes and broad cache deletion.

Alligator is only the launcher, configuration and diagnostics workspace. The actual rendering corrections must be implemented and validated in the external VIctory/DexNom renderer source; changing Alligator documentation or profiles alone cannot fix skin, eye, hair, texture or lighting shaders.
