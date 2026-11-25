# Rendering and performance research

Research snapshot: 25 November 2026. Public fork results are single-machine observations, not forecasts for another GPU.

## What the user's capture proves

The DexNom Ultra v0.6 HUD shows approximately:
- 0.7 FPS and 1,437.9 ms/frame
- 3,577 draws/frame
- 3,455 draws/frame reported as dropped without a host pipeline
- GPU wait 408.8 ms, CPU prep 555.0 ms, copy-back 451.6 ms
- 3,035 MB process RAM

The dropped counter is not ordinary display-frame loss. The renderer reports draws/dispatches that have no host pipeline, including shaders that did not translate, pipelines refused by the D3D12 driver, and pipelines not ready within the current frame's budget. This can plausibly explain missing skin/material/geometry. The HUD alone cannot tell which reason dominates; the matched runtime log does.

The diagnostic timing categories can overlap. GPU wait is time attributed to waiting for submitted GPU work, not a direct GPU-utilization measurement. The v0.6 source implements the counters in `crates/victory-gpu/src/host.rs`, `pipeline.rs` and `pipeline/host.rs`.

The v0.6 source is based on the upstream snapshot documented in its manifest. Its own changelog says the v0.6 visual changes do not complete the game's ray-traced lighting, shader coverage or all materials. Its default `UltraVisual1080` profile enables material-demand sampling and additional early/bake texture work (24 ms / 2500 ms). `UltraSafe1080` omits those experiments and is a better comparison baseline; neither profile is a renderer rewrite.

## Public projects reviewed

### Marvisak/VIctory

The upstream runtime and D3D12/shader translation base:
https://github.com/Marvisak/VIctory

### fxceless/victory-fork

README snapshot dated 25 November 2026 reports 8–10 FPS in first rooms on one Windows 11 PC with an RTX 4070 12 GB, but shadowed areas remain black. Its README documents opt-in asynchronous submission, queue scheduling, indirect draw handling, card-memory buffer placement and shader changes. These are a divergent codebase and a different GPU. Some latest experiments are explicitly unmeasured or have unresolved stability problems:
https://github.com/fxceless/victory-fork

### Belobug/VIctory-Belobug-AMD

README snapshot dated 25 November 2026 reports 5–8 FPS on a single RX 9070 XT 16 GB, Ryzen 7 9800X3D and 64 GB RAM. It contains AMD-focused corrections for helper-pixel/quad reads (including skin), blend-shape skinning, hair/material shaders, integer targets, shadow/depth handling and GPU memory. It uses an ambient-light approximation that follows the sky because the game's ray-traced indirect lighting is not yet working. The README still lists missing in-game phone rendering and very high memory use. RX 9070 XT 16 GB is substantially more capable than this user's RX 7600 8 GB, so the reported FPS is not transferable:
https://github.com/Belobug/VIctory-Belobug-AMD

### WillyboPeep/victory-all-forks

This is explicitly a test merge of upstream and community forks, not an original implementation. Its documentation lists changes relevant to the user's defects: meshlet culling, descriptor exhaustion, GPU-written light readback, fog, shadow masks, hair, blend-shape skinning, fire and material shaders. The README reports a 5.7 FPS result in one matched view on an RTX 4090 24 GB after selected changes; other test figures are lower. It still lists black shadows and incomplete ray tracing:
https://github.com/WillyboPeep/victory-all-forks
https://github.com/WillyboPeep/victory-all-forks/blob/main/ALL-FORKS.md

### XCL

XCL is a separate Xbox compatibility project. Its GPL-2.0-only license is not a drop-in license match for VIctory's GPL-3.0-or-later code. Use it as a reference for concepts only unless legal compatibility is established:
https://github.com/ivall/xcl

## What to do next on the RX 7600

1. Let the current game session end normally so v0.6 exports its matched post-game report. Review local paths/account folder names before sharing.
2. Inspect `last-runtime-lines.txt` and `first-graphics-events.txt` for repeated lines such as `shader does not translate`, `host pipeline refused`, `no host pipeline`, `not implemented`, texture memory/budget warnings, or device removal.
3. Run the same save/scene/camera using `UltraSafe1080` as the comparison. Do not change caches or several experimental switches together.
4. Only then choose a renderer branch/patch. Prefer a separate experimental checkout and separate runtime so the known-working v0.6 binaries remain available for rollback.
5. Port one compatible GPL-3.0-or-later change at a time, keep original authors/commit history and license notices, rebuild, then compare the same scene.

Do not import RX 4090/4070/9070 XT memory sizes or performance switches wholesale into an RX 7600 8 GB setup. In particular, a 4096 MB card-window setting measured on a 24 GB RTX 4090 is not a safe default for an 8 GB card. Do not use RT or driver timeout/registry hacks as an FPS shortcut.
