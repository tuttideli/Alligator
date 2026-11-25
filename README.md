# Alligator

Alligator is the public Windows launcher and maintenance workspace for a local DexNom Ultra / VIctory installation.

It keeps orchestration, profile selection, diagnostics and self-update logic separate from the game and renderer source. The game, renderer source, shader cache and saves remain on the user's PC.

## Included

- `Alligator.ps1`: Windows PowerShell 5.1 entry point for Launch, Build, Doctor, Profiles, Rollback, Report, Collect, TestAMD and Update.
- `Start-Alligator.cmd`: double-click launcher for the normal DexNom Ultra v0.6 profile.
- `updater/Update.ps1`: fast-forward-only Git self-update for a clean Alligator checkout. It updates this repository only.
- `experiments/Start-AMD-Fork.ps1`: isolated build/run of a reviewed AMD-oriented VIctory fork snapshot. It does not replace the existing DexNom Ultra runtime.
- Local config is created from `config/settings.example.json`; the actual `config/settings.json` is ignored by Git.
- Windows CI validates PowerShell syntax and JSON and rejects tracked game/runtime artifacts.

## One-time setup

1. Install Git for Windows, Rust for Windows and Visual Studio Build Tools with Desktop development with C++, x64 MSVC tools and a Windows 10/11 SDK.
2. Clone the repository:
   ```powershell
   cd "$env:USERPROFILE\Downloads"
   git clone https://github.com/tuttideli/Alligator.git
   cd .\Alligator
   ```
3. Run `.Alligator.ps1 -Action Doctor`. The first run creates `config/settings.json`.
4. Edit `config/settings.json` and set `gameExecutable` to your own `game_scarlett_master.exe`. Confirm `engineSourceDirectory` points to the existing `DexNom-UltraPerformance-v0.1` source checkout.
5. Start the normal runtime with `.Start-Alligator.cmd`.

## Commands

```powershell
.\Alligator.ps1 -Action Doctor
.\Alligator.ps1 -Action Profiles
.\Alligator.ps1
.\Alligator.ps1 -Profile UltraSafe1080
.\Alligator.ps1 -Profile Display720
.\Alligator.ps1 -Action Report
.\Alligator.ps1 -Action Collect
.\Alligator.ps1 -Action Build
.\Alligator.ps1 -Action Rollback
.\Alligator.ps1 -Action Update
```

The default profile is `UltraSafe1080`. It omits v0.6's material-demand and long texture-bake experiments. This is a controlled baseline, not a promise of high FPS. `Display720` changes the title display mode; it does not guarantee a lower internal render resolution.

## Experimental AMD renderer

The v0.6 DexNom renderer is extremely incomplete on the user's RX 7600: the observed HUD showed roughly 0.7 FPS and about 3,455 draws per frame without a host pipeline. This metric combines untranslated/refused shaders and pipelines still being created; the detailed runtime log is needed to identify the mix.

For a separate comparison, run:

```powershell
.\Alligator.ps1 -Action TestAMD
```

This clones and builds a pinned public AMD-oriented VIctory fork under `%LOCALAPPDATA%\Alligator\engines`, with its cache and user data isolated under `%LOCALAPPDATA%\Alligator\data`. It leaves the current DexNom v0.6 engine and caches untouched.

The reviewed fork snapshot documents AMD-specific corrections for helper-pixel/quad reads (relevant to skin edges), blend-shape skinning, hair/material shaders, depth/shadows and an ambient-light approximation that follows the sky. The ambient approximation is not full ray-traced global illumination. The fork's published 5–8 FPS result was measured on an RX 9070 XT 16 GB, not an RX 7600 8 GB, so it is not a prediction for this PC.

Optional hair shader test (experimental; may produce more missing pipelines or instability):

```powershell
.\Alligator.ps1 -Action TestAMD -EnableHairExperiment
```

Do not enable experimental ray tracing on this fork: its own README reports device removal during ray-enabled runs. The first world load may take minutes while pipelines are created. Do not judge performance during cold shader compilation.

## Important separation

- Alligator self-updates from this Git repository.
- The stable DexNom v0.6 renderer is built/installed using its original external `ultra/Build-Ultra.ps1`.
- The AMD test is a separate engine checkout, separate executable, separate cache and separate local data.
- No renderer source from another project is copied into this repository by the launcher. Any future port must preserve author attribution, project history and GPL-3.0-or-later obligations.

## Repository safety

Do not commit game files, game executables, saves, shader caches, runtime caches, memory dumps, personal diagnostic logs, access tokens or credentials. Review reports before sharing because diagnostic logs can contain local paths and account folder names.

## Current status

Alligator is a launcher/orchestration layer and research workspace. It is not yet a performance patch to the D3D12 renderer and does not claim to make the game fully playable.

Research and known limitations:
- `docs/RESEARCH-AND-PERFORMANCE.md`
- `docs/DIAGNOSTICS.md`
- `docs/PROFILE-GUIDE.md`
- `docs/UPDATE-DESIGN.md`
