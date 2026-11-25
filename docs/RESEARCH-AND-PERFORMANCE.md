# Rendering and performance research

Research snapshot: 25 November 2026. Public fork results are single-machine observations, not forecasts for another GPU.

## What the user's capture proves

The DexNom Ultra v0.6 HUD shows approximately:
- 0.7 FPS and 1,437.9 ms/frame
- 3,577 draws/frame
- 3,455 dropped draws/frame without a ready host pipeline
- GPU wait 408.8 ms, CPU preparation 555.0 ms, copy-back 451.6 ms
- 3,035 MB process RAM

The code defines a host pipeline as unavailable when one of its shaders does not translate, the host driver refuses the pipeline, or the pipeline is still being made. The dropped count aggregates these causes. It is therefore evidence of major renderer pipeline coverage/creation problems, but the HUD number alone cannot identify which shader or driver failure dominates. The matching detailed runtime log is needed.

The timing categories can overlap. GPU wait is the renderer's CPU-side wait for submitted GPU work, not a direct hardware utilization reading. The source records the aggregate and per-reason drop messages in `crates/victory-gpu/src/pipeline.rs` and `host.rs`.

The v0.6 `UltraVisual1080` profile enables material-demand sampling plus early/bake texture work (24 ms / 2500 ms). The source changelog itself warns this may lengthen loading or lower FPS. `UltraSafe1080` disables those two experiments and is a better controlled baseline. Neither repairs missing translated shaders.

## Public projects reviewed

### Marvisak/VIctory
Base runtime, D3D12 backend and shader translator:
https://github.com/Marvisak/VIctory

### fxceless/victory-fork
README snapshot dated 25 November 2026 reports 8–10 FPS in the first rooms on one Windows 11 PC with an RTX 4070 12 GB, while shadowed areas remain black. It documents opt-in submission scheduling, indirect drawing, card-memory placement, copy batching and shader changes. This is a divergent codebase and a different GPU; some newer experiments are unmeasured or have unresolved stability issues:
https://github.com/fxceless/victory-fork

### Belobug/VIctory-Belobug-AMD
README snapshot dated 25 November 2026 reports 5–8 FPS on one RX 9070 XT 16 GB, Ryzen 7 9800X3D and 64 GB RAM. It documents AMD-specific changes for helper-pixel/quad reads, blend-shape skinning, hair/material shaders, integer render targets, depth/shadows and GPU memory. It also uses an ambient-light approximation that follows the sky because full ray-traced indirect light is not working. The README still lists known missing shaders, high memory use and a broken in-game phone scene. RX 9070 XT 16 GB is substantially more capable than the user's RX 7600 8 GB; the published FPS result is not transferable:
https://github.com/Belobug/VIctory-Belobug-AMD

Reviewed experiment commit: `4f62c2a5e27e7beebf3e8d68f77898e43dc7b77c`.

### WillyboPeep/victory-all-forks
This is explicitly a test merge of upstream and community forks, not an original implementation. Its documentation lists fixes relevant to the reported defects: meshlet culling, descriptor exhaustion, GPU-written light readback, fog, shadow masks, hair, blend-shape skinning, fire and material shaders. It reports a 5.7 FPS result in one matched view on an RTX 4090 24 GB after selected changes; other test runs are lower. It still lists black shadows and incomplete ray tracing:
https://github.com/WillyboPeep/victory-all-forks
https://github.com/WillyboPeep/victory-all-forks/blob/main/ALL-FORKS.md

### XCL
XCL is a separate Xbox compatibility project with a different renderer/translator and GPL-2.0-only licensing. Its code is not a drop-in source for the GPL-3.0-or-later VIctory-derived engine. It is a reference for ideas only unless license compatibility is established:
https://github.com/ivall/xcl

## Practical plan for RX 7600 8 GB

1. Preserve the known-working v0.6 runtime and its shader cache.
2. First test `UltraSafe1080` against the current profile under the same save, camera and scene. Do not change cache state or several profile variables together.
3. Test the isolated AMD fork using `Alligator.ps1 -Action TestAMD`. It builds the reviewed commit in a separate folder with separate cache and save/data directories. Compare after shader/pipeline creation has settled.
4. If skin/hair is still missing, run the optional `-EnableHairExperiment` test as a separate run. The fork README says some hair/ray-related shaders still fail to translate, so this is not a guaranteed correction.
5. Inspect `Dropped ... without a host pipeline: <reason>` lines from the per-run log. Port only a specific fix that matches the observed reason, with author attribution and compatible license.
6. Benchmark one change at a time and keep a binary rollback.

Do not import memory settings tuned for 12/16/24 GB GPUs into an 8 GB RX 7600. Do not enable ray tracing on the AMD test fork: its own README reports device removal during ray-enabled sessions. Avoid registry/TDR changes and broad cache deletion.

The immediate target is to reduce missing host pipelines and render the scene correctly; only then can FPS tuning be meaningfully measured.
