# Reading Alligator / DexNom diagnostics

## HUD fields

- `FPS` and `ms/frame`: presentation rate and frame interval.
- `draws/frame`: draw workload observed by the runtime.
- `GPU wait`: time spent waiting for submitted GPU work; it is not GPU utilization.
- `CPU prep`: time attributed to CPU-side frame preparation.
- `Copy-back`: time in the title-memory copy-back path.
- `Dropped`: draws/dispatches counted because a host pipeline was unavailable, untranslated, refused, or still being made. It is not the number of frames discarded by the display.

Diagnostic timing categories can overlap and should not be added as if they were exclusive slices of one stopwatch.

## What to collect after a run

The v0.6 Start-Ultra script automatically exports a post-game report after a confirmed session end. It creates a folder under Downloads named `DexNom-Ultimo-Jogo-...`. It can include:
- `report-index.json`: session identity, provenance and limitations.
- `runtime-logs`: matched raw runtime logs.
- `session-reports`: parsed metrics and selected events.
- `first-graphics-events.txt` and `last-runtime-lines.txt`: useful context for missing pipelines and device errors.
- `windows-events.json`: selected Windows display, hardware and application events.

Before sharing, review local paths and account-folder names. Do not send game files, caches, saves or memory dumps.

## Controlled comparisons

Keep the same save, camera, scene, profile family and cache state. Let streaming settle before measuring. Change one profile or code change per run. Stop testing after a GPU device removal or system driver reset; inspect the report before relaunching.
