# Rendering and performance research

Research snapshot: 25 November 2026. Findings below are from public project documentation and are not promises of performance on another GPU.

## Why the current 0.7–0.8 FPS matters

The v0.6 runtime HUD in the user's capture shows approximately:
- 0.7 FPS and 1,437.9 ms/frame
- 3,577 draws/frame
- 3,455 draws or dispatches/frame without a ready host pipeline
- 408.8 ms GPU wait, 555.0 ms CPU preparation and 451.6 ms copy-back
- 3,035 MB process RAM

In this renderer, the dropped counter is not a count of ordinary missed presentation frames. Diagnostics count draws/dispatches skipped because no host pipeline exists, including untranslated/refused shaders and pipelines that are not ready. The detailed log should name the reason for each drop. Therefore, skin/material/geometry gaps may be shader or pipeline-coverage problems, not simply low texture quality.

The three timing values are diagnostic timings and may overlap. GPU wait is CPU-side waiting for GPU work to complete, not a direct measurement of GPU utilization. See `crates/victory-gpu/src/pipeline.rs` and `host.rs` in the local v0.6 source for the counter implementation and HUD.

## Projects worth studying

### Marvisak/VIctory

The upstream project is the base runtime and documents that the world renderer remains incomplete, with missing shaders/pipelines and very long frame times. The user's local DexNom v0.6 build is a community fork and not equivalent to the latest upstream state.

- https://github.com/Marvisak/VIctory

### fxceless/victory-fork

Its 25 November 2026 README reports 8–10 FPS in the first rooms on one Windows 11 PC with an RTX 4070 12 GB, but shadowed areas remain black. The README also describes multiple opt-in changes: asynchronous submission, queue scheduling, indirect-draw handling, card-memory buffer placement, copy batching, staging pools and shader cleanup. The high FPS figure uses a bundle of switches and a different codebase/GPU; it is not a valid RX 7600 prediction.

- https://github.com/fxceless/victory-fork

### Belobug/VIctory-Belobug-AMD

Its 25 November 2026 README reports 5–8 FPS on a single RX 9070 XT 16 GB test machine. It has explicit AMD fixes for quad/helper-pixel reads, integer target blending, depth twins and GPU memory handling. It also implements a sky-following ambient-light approximation because the game's ray-traced indirect light is not available. The README says the approximation is not true ray-traced global illumination and lists remaining issues, including the in-game phone and high memory use.

This is the closest public AMD reference found, but RX 9070 XT 16 GB is a much higher-tier card than the user's RX 7600 8 GB. It must be ported selectively and measured; do not transplant its entire renderer blindly.

- https://github.com/Belobug/VIctory-Belobug-AMD

### victory-all-forks

This test merge documents fixes that directly match the visible defects being reported: meshlet culling, descriptor-table exhaustion, GPU-written light-buffer readback, fog reconstruction, shadow masks, hair, blend-shape skinning, fire and several material shaders. It reports 2.5–4 FPS on one RTX 4070 PC in its own test snapshot, with black shadow areas still listed as a known issue. The repository describes itself as a merge/test project, not an original fork.

Its source history and authors must be preserved if any of those GPL-3.0-or-later changes are ported.

- https://github.com/WillyboPeep/victory-all-forks
- https://github.com/WillyboPeep/victory-all-forks/blob/main/ALL-FORKS.md

### XCL

XCL is a separate Xbox Series compatibility layer with a different renderer/translator and GPL-2.0-only licensing. Its engineering notes document background pipeline creation, shader/DXIL caching, precompilation and GPU memory windows. These are useful design references, but GPL-2.0-only code must not be copied into the GPL-3.0-or-later VIctory-derived engine without a compatible licensing basis. We can independently implement compatible ideas in Alligator's PowerShell orchestration and evaluate renderer techniques separately.

- https://github.com/xcl-dev/xcl
- https://github.com/xcl-dev/xcl/blob/main/HANDOFF.md

## Immediate test plan for the RX 7600

1. Export the current v0.6 post-game report. The report's per-run log includes the detailed reasons behind `Dropped ... without a host pipeline`.
2. Compare the same save, camera and scene with `UltraSafe1080` against the current `UltraVisual1080`. UltraVisual1080 enables material-demand sampling and an early/bake texture pass (24 ms / 2,500 ms). UltraSafe1080 keeps the visual presentation path but leaves those two experiments off.
3. Test `UltraPerf1080` separately; it adds a card-rehash experiment and is not proven faster on an RX 7600.
4. Only after the dropped-pipeline reasons are known, select one renderer fix at a time from the compatible GPL-3.0-or-later fork history. Rebuild, preserve the shader cache, compare the same scene and keep a binary rollback available.

Do not use RT, driver timeouts, registry/TDR changes, broad cache deletion, or several experimental switches together as an FPS shortcut. The target is correct rendering first, then repeatable frame-time reductions.
