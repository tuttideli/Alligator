# v0.6 profile guide

Alligator launches the existing DexNom v0.6 `Start-Ultra.ps1`; it does not inject additional undocumented `VICTORY_*` environment variables.

| Profile | What it changes | Use |
|---|---|---|
| `UltraSafe1080` | Ultra 1080 path and visibility lift; no material-demand sampling or long early/bake texture pass | Recommended first comparison |
| `UltraPerf1080` | Ultra 1080 path plus card rehash experiment | A/B test separately; not proven on RX 7600 |
| `UltraVisual1080` | Adds material-demand sampling, 24 ms early texture work and 2,500 ms bake window | Visual/streaming experiment; may cost time |
| `UltraVisualStrong1080` | Same material experiment with stronger visibility lift | Visual experiment |
| `UltraLightingTrace1080` | Enables extra wall tracing and card accounting | Diagnostics only; not an FPS profile |
| `Display720` | Reports 1280x720 as a title display mode | Compatibility experiment; not guaranteed to reduce internal rendering load |
| `Workers4` | Four workers for eligible fill work | CPU-path experiment |
| `Preludes` | Parallel command-list prelude recording | Scene-dependent experiment |
| `Baseline` | Default runtime environment | Reference |

All environment settings are process-local and selected by the source launcher. OnceLock-backed settings require a new runtime process. Never assume that a profile improves performance without a same-scene comparison.
