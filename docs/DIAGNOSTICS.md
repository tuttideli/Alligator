# Reading Alligator / DexNom diagnostics

## HUD fields

- FPS and ms/frame: presentation rate and frame interval.
- draws/frame: draw workload observed by the runtime.
- GPU wait: time spent waiting for submitted GPU work; it is not GPU utilization.
- CPU prep: time attributed to CPU-side frame preparation.
- Copy-back: time in the title-memory copy-back path.
- Dropped: draws/dispatches counted because a host pipeline was unavailable, untranslated, refused, or still being made. It is not the number of frames discarded by the display.

Diagnostic timing categories can overlap and should not be added as if they were exclusive slices of one stopwatch.

## Current RX 7600 symptoms (25 November 2026)

The later indoor screenshot shows ceiling fixtures emitting light while much of the room remains very dark; character materials and surface detail are incomplete. The latest exterior screenshot still shows incomplete characters/materials, a highly washed-out bright surface and poor scene detail. These are renderer presentation/coverage symptoms, not something a desktop brightness slider can reliably repair.

The accompanying runtime log initially reported roughly 29-30 FPS while it was drawing only 6-13 draws per frame. Once the scene became complex, samples fell to about 0.2-1.1 FPS, with thousands of draws, hundreds to thousands of dropped draws, and a texture queue that rose above 18,000 entries. One sample reported 6,304 dropped draws; another reported 1.1 FPS with roughly 1,158 draws, 580 dropped draws and about 10,414 pending textures. The log also showed the local-memory counter reaching roughly 7.5 GiB against a displayed budget near 6.3 GiB, plus repeated buffer-view refusals.

These observations do not prove that one counter alone causes every visual defect. They do show that the early 30 FPS readings were not representative of the fully populated scene and that both renderer coverage and resource pressure need attention.

A closer RX 7600 comparison is now available in the isolated Peau3 experiment. Its documented Windows run used an RX 7600 8 GB with 32 GB RAM and a 32 GB page file, reaching about 6.2-6.5 FPS in the tested prison scene with characters, hair, skin and environment rendered. It held about 21 GB of memory. This is not a result for a 16 GB system-RAM machine; the launcher deliberately prompts before a low-memory test.

## Run and analyze a controlled baseline

From the Alligator folder, run:

    .\Start-Baseline-Diagnostic.ps1

This wrapper always launches the existing Baseline profile and enables raw logging. It does not rebuild the renderer, delete shader caches, change game files or patch shaders.

After closing the game/runtime, run:

    .\Analyze-LastRendererRun.ps1

The analyzer selects the newest run-*.log under the configured runtime's logs folder and creates a text summary in Downloads. It reports:
- Total frame samples and samples with 500 or more draws (a rough heavy-scene filter, not a formal benchmark).
- Median FPS and frame time for those heavy-scene samples.
- Maximum dropped draws, pending textures and unmapped textures observed.
- Maximum local-memory use and its displayed budget.
- Lines about missing host pipelines, refused buffer views, shader translation, root signatures and device removal.

The analyzer is read-only with respect to the runtime. It does not modify the game, renderer, settings, caches or saves. The report may still contain local paths; review it before sharing.

Keep the same save, camera, scene and cache state. Let shader and texture streaming settle before measuring. A menu or loading-screen FPS result is not a world-scene benchmark.

## RX 7600 Peau3 comparison

Use the separate command `.Alligator.ps1 -Action TestRX7600` to build the reviewed Peau3 commit. This is a different renderer executable with its own cache and data folders. It is the best matching public test located for an RX 7600 8 GB, but it was measured with 32 GB RAM and a large page file. The script does not change the current DexNom installation.

The result is still experimental: black/chrome material artifacts and delayed textures were reported. Do not combine the untested `fix/partly-clamp` branch with this baseline before a clean Windows build and controlled comparison.
## What to collect after a run

The v0.6 Start-Ultra script automatically exports a post-game report after a confirmed session end. It creates a folder under Downloads named DexNom-Ultimo-Jogo-.... It can include:
- report-index.json: session identity, provenance and limitations.
- runtime-logs: matched raw runtime logs.
- session-reports: parsed metrics and selected events.
- first-graphics-events.txt and last-runtime-lines.txt: useful context for missing pipelines and device errors.
- windows-events.json: selected Windows display, hardware and application events.

Before sharing, review local paths and account-folder names. Do not send game files, caches, saves or memory dumps.

## Controlled comparisons

Change one profile or code change per run. Do not combine UltraVisual, memory-budget changes and shader experiments in one test. Stop testing after a GPU device removal or system driver reset; inspect the report before relaunching.
