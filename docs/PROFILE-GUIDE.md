# DexNom Ultra v0.6 profile guide

Alligator passes the selected profile to the existing `ultra/Start-Ultra.ps1`. It does not set undocumented `VICTORY_*` environment variables itself.

| Profile | v0.6 behavior | Use |
|---|---|---|
| `UltraSafe1080` | Ultra 1080 display mode and visibility lift; no material-demand sampling or long early/bake texture pass | Recommended first A/B baseline |
| `UltraPerf1080` | Ultra 1080 path plus card rehash experiment | Test separately; not proven faster on RX 7600 |
| `UltraVisual1080` | Adds material-demand sampling, 24 ms early texture work and 2500 ms bake window | Visual/streaming experiment; may increase frame work |
| `UltraVisualStrong1080` | UltraVisual1080 with stronger visibility lift | Visual experiment |
| `UltraLightingTrace1080` | Adds wall tracing and card accounting diagnostics | Diagnostic overhead; not an FPS profile |
| `Display720` | Reports 1280x720 as the title display mode | Does not guarantee reduced internal render resolution |
| `Workers4` | Four workers for eligible fill/upload work | Narrow CPU-path experiment |
| `Preludes` | Parallel recording of eligible command-list preludes | Scene-dependent |
| `Smooth` | Disables texture catch-up | Changes streaming behavior |
| `VRAM85` | Sets texture-room percent to 85 | Memory trade-off; monitor missing textures |
| `Baseline` | No named v0.6 profile-specific renderer tuning | Reference |

The AMD fork experiment is separate from these profiles. It uses a distinct checkout and cache/data paths; it does not share the v0.6 cache. Its optional hair flag is experimental. Its sky-following ambient approximation is enabled by default in the reviewed commit, but it is not full ray-traced global illumination.

Environment settings are process-local and some are initialized once per process. Every comparison requires a new runtime process and the same save, camera, scene and cache conditions.
