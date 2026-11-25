# Alligator

Alligator is the public Windows launcher and maintenance workspace for a local DexNom Ultra / VIctory installation.

It keeps orchestration, profile selection, diagnostics and self-update logic separate from the game and renderer source. The game, renderer source, shader cache and saves remain on the user's PC.

## Included

- Alligator.ps1: Windows PowerShell 5.1 entry point for Launch, Build, Doctor, Profiles, Rollback, Report, Collect, TestAMD and Update.
- Start-Alligator.cmd: double-click launcher for the normal DexNom Ultra v0.6 profile.
- Start-Baseline-Diagnostic.ps1: launches the unmodified Baseline profile with raw logging for controlled visual/performance diagnosis.
- Analyze-LastRendererRun.ps1: summarizes the latest runtime log, including heavy-scene frame samples, dropped draws, texture backlog, memory counters and graphics warnings.
- updater/Update.ps1: fast-forward-only Git self-update for a clean Alligator checkout. It updates this repository only.
- experiments/Start-AMD-Fork.ps1: isolated build/run of a reviewed AMD-oriented VIctory fork snapshot. It does not replace the existing DexNom Ultra runtime.
- Local config is created from config/settings.example.json; the actual config/settings.json is ignored by Git.
- Windows CI validates PowerShell syntax and JSON and rejects tracked game/runtime artifacts.

## One-time setup

1. Install Git for Windows, Rust for Windows and Visual Studio Build Tools with Desktop development with C++, x64 MSVC tools and a Windows 10/11 SDK.
2. Clone the repository:

       cd "$env:USERPROFILE\Downloads"
       git clone https://github.com/tuttideli/Alligator.git
       cd .\Alligator

3. Run .\Alligator.ps1 -Action Doctor. The first run creates config/settings.json.
4. Edit config/settings.json and set gameExecutable to your own game_scarlett_master.exe. Confirm engineSourceDirectory points to the existing DexNom-UltraPerformance-v0.1 source checkout.
5. Start the normal runtime with .\Start-Alligator.cmd.

## Commands

    .\Alligator.ps1 -Action Doctor
    .\Alligator.ps1 -Action Profiles
    .\Alligator.ps1
    .\Alligator.ps1 -Profile UltraSafe1080
    .\Alligator.ps1 -Profile Display720
    .\Start-Baseline-Diagnostic.ps1
    .\Analyze-LastRendererRun.ps1
    .\Alligator.ps1 -Action Report
    .\Alligator.ps1 -Action Collect
    .\Alligator.ps1 -Action Build
    .\Alligator.ps1 -Action Rollback
    .\Alligator.ps1 -Action Update

The default profile is UltraSafe1080. It omits v0.6's material-demand and long texture-bake experiments. This is a controlled comparison profile, not a promise of high FPS. Display720 changes the title display mode; it does not guarantee a lower internal render resolution.

### Dark interiors, missing textures or unstable FPS

Run Start-Baseline-Diagnostic.ps1 for an A/B baseline. It explicitly launches the existing Baseline profile and enables raw logging, regardless of the profile saved in local settings.json. It does not rebuild the renderer, delete shader caches, change the game files or claim to fix unsupported shaders.

After closing the session, run:

    .\Analyze-LastRendererRun.ps1

The analyzer reads only the newest runtime log under %LOCALAPPDATA%\DexNom Ultra Performance v0.1\logs and writes a text summary under Downloads. It reports heavy-scene samples (500+ draws), frame timing, dropped draws, pending/unmapped textures, local-memory counters and selected graphics warnings. It does not modify the runtime or copy game data. Review local paths before sharing the report.

Baseline is a diagnostic reference with no named v0.6 profile-specific renderer tuning. Compare it with UltraSafe1080 in the same save, camera position and scene. A better-looking frame or a higher menu FPS alone is not proof that the world renderer is fixed.

## Experimental AMD renderer

The v0.6 DexNom renderer is extremely incomplete on the user's RX 7600: earlier HUD captures showed roughly 0.7 FPS, thousands of draws without a ready host pipeline, a large texture queue and heavy copy-back work. These counters indicate missing renderer work; they do not identify one single root cause.

For a separate comparison, run:

    .\Alligator.ps1 -Action TestAMD

This clones and builds a pinned public AMD-oriented VIctory fork under %LOCALAPPDATA%\Alligator\engines, with its cache and user data isolated under %LOCALAPPDATA%\Alligator\data. It leaves the current DexNom v0.6 engine and caches untouched.

Important hardware warning: the fork's 25 November 2026 README reports 5-8 FPS on one RX 9070 XT 16 GB system with 64 GB RAM, about 22 GB of system RAM use and more video memory than a 16 GB card has. It uses an approximation for indirect ambient light; the game's ray-traced bounce light still does not run. This result is not a performance forecast for an RX 7600 8 GB.

There is also an open Windows 10 report for an RX 7600 8 GB where that fork crashed at frame 0 after the host rejected root-signature flags. This is one report on a particular build, not proof that every run fails, but it is a strong reason not to treat TestAMD as a safe FPS upgrade for an 8 GB card. See:
- https://github.com/Belobug/VIctory-Belobug-AMD
- https://github.com/Belobug/VIctory-Belobug-AMD/issues/168

The optional hair shader test remains experimental:

    .\Alligator.ps1 -Action TestAMD -EnableHairExperiment

Do not enable experimental ray tracing on this fork. The first world load may take minutes while pipelines are created. Do not judge performance during cold shader compilation.

## Important separation

- Alligator self-updates from this Git repository.
- The stable DexNom v0.6 renderer is built/installed using its original external ultra/Build-Ultra.ps1.
- The AMD test is a separate engine checkout, separate executable, separate cache and separate local data.
- No renderer source from another project is copied into this repository by the launcher. Any future port must preserve author attribution, project history and GPL-3.0-or-later obligations.

## Repository safety

Do not commit game files, game executables, saves, shader caches, runtime caches, memory dumps, personal diagnostic logs, access tokens or credentials. Review reports before sharing because diagnostic logs can contain local paths and account folder names.

## Current status

Alligator is a launcher/orchestration layer and research workspace. It is not yet a performance patch to the D3D12 renderer and does not claim to make the game fully playable.

Research and known limitations:
- docs/RESEARCH-AND-PERFORMANCE.md
- docs/DIAGNOSTICS.md
- docs/PROFILE-GUIDE.md
- docs/UPDATE-DESIGN.md
