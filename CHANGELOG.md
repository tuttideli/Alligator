# Changelog

## 0.1.3 - 2026-11-25
- Add isolated TestRX7600 / Peau3 renderer runner pinned to the RX 7600-tested commit b74ac64.
- Add RAM/page-file preflight and a separate confirmation for low-memory runs.
- Add optional local PC FidelityFX SDK path for the measured 1080p-to-4K test profile.
- Keep the Peau3 engine, release build, cache, data and logs separate from DexNom v0.6.

## 0.1.2 - 2026-11-25
- Add Analyze-LastRendererRun.ps1 to summarize heavy-scene FPS, dropped draws, texture backlog, memory counters and graphics warnings from the latest runtime log.
- Expand diagnostic guidance for incomplete characters/materials and overexposed scene surfaces.
- Keep Alligator read-only against game, runtime binaries, caches and saves during log analysis.

## 0.1.1 - 2026-11-25
- Add Start-Baseline-Diagnostic.ps1 to launch the unmodified Baseline profile with raw logging.
- Document the current RX 7600 scene/texture queue and dropped-pipeline symptoms.
- Add current AMD fork memory and RX 7600 compatibility cautions.
- Clarify that Alligator is an orchestration layer and does not itself patch renderer shaders or lighting.

## 0.1.0 - 2026-11-25
- Add the Alligator PowerShell control entry point and double-click launcher.
- Add safe fast-forward-only self-update for a clean Alligator checkout.
- Add Doctor, profile listing, build, report, diagnostics collection and rollback orchestration for the existing DexNom Ultra v0.6 source.
- Set UltraSafe1080 as the default comparison profile instead of the more expensive UltraVisual1080 experiment.
- Add an isolated AMD-oriented VIctory fork experiment pinned to a reviewed commit, with separate engine/cache/data directories.
- Add research notes for AMD skin/helper-pixel fixes, blend-shape skinning, hair/material shaders, ambient-light approximation, and renderer performance bottlenecks.
- Add Windows CI for PowerShell syntax, JSON validation and repository artifact safety.
- No game files or renderer source were copied into Alligator; the existing DexNom v0.6 runtime remains unchanged.
