# Alligator

Alligator is the public Windows launcher and maintenance workspace for a local DexNom Ultra / VIctory installation.

It keeps orchestration, profile selection, diagnostics and self-update logic separate from the game and renderer source. The game, renderer source, shader cache and saves remain on the user's PC.

## Included

- Alligator.ps1: Windows PowerShell 5.1 entry point for Launch, Build, Doctor, Profiles, Rollback, Report, Collect, TestAMD, TestRX7600 and Update.
- Start-Alligator.cmd: double-click launcher for the normal DexNom Ultra v0.6 profile.
- Start-Baseline-Diagnostic.ps1: launches the unmodified Baseline profile with raw logging for controlled visual/performance diagnosis.
- Analyze-LastRendererRun.ps1: summarizes the latest runtime log, including heavy-scene frame samples, dropped draws, texture backlog, memory counters and graphics warnings.
- updater/Update.ps1: fast-forward-only Git self-update for a clean Alligator checkout. It updates this repository only.
- experiments/Start-AMD-Fork.ps1: isolated build/run of a reviewed AMD-oriented VIctory fork snapshot.
- experiments/Start-RX7600-Peau3.ps1: isolated release build/run of a VIctory fork commit measured on an RX 7600 8 GB.
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
    .\Alligator.ps1 -Action TestRX7600

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

## RX 7600-tested renderer experiment (Peau3)

A separate community fork reports a Windows test on an AMD RX 7600 8 GB: about 6.2-6.5 FPS in the tested prison scene, with buildings, cells, characters, hair, skin and sky rendered. That run used 32 GB physical RAM, a 32 GB page file and about 21 GB of memory during a 10-minute session. It is the closest public hardware match found for the user's RX 7600, but it is not a guarantee for other scenes or a 16 GB system-RAM configuration.

Alligator pins the exact measured Peau3 source commit (`b74ac64da2e289cc632980cf8e508c2d1ba909ac`) and builds/runs it in separate engine, build, cache, data and log folders. It does not replace or rebuild DexNom v0.6, change game files, change registry/TDR settings or delete existing caches.

The tested profile needs the PC FidelityFX SDK file `amd_fidelityfx_upscaler_dx12.dll` to render internally at 1080p and upscale to 4K. Set `fidelityFxDirectory` in local `config/settings.json`, pass `-FidelityFxDir`, or provide the path when prompted. The first release build and first shader/pipeline load can take time.

Run:

    .\Alligator.ps1 -Action TestRX7600

The fork's measured setup used `VICTORY_TEXTURE_HALF=2`, `VICTORY_STAGING_POOL_MB=1024`, `VICTORY_VRAM_HYSTERESIS=85,75`, `VICTORY_AMBIENT=off`, `VICTORY_WAVE_WIDE=1`, `VICTORY_SHADER_OPT=0` and FSR scale 0.5. The launcher applies the full Peau3 environment from the fork's handoff notes. It requires a separate explicit `TEST` confirmation before launching. On systems with less than 32 GB RAM, it also warns and asks for `LOW-RAM-TEST`; the run can page heavily, stutter or fail. It refuses to continue when the currently allocated page file is under 20 GB. Alligator will not enlarge the page file automatically.

Known limitations from the fork's own handoff: random chrome/black texture artifacts can remain on clothes, faces and posters; streamed textures can arrive late; this is still an experimental compatibility runtime, not a fully playable console-equivalent build. A separate unbuilt `fix/partly-clamp` branch targets partially streamed texture mips, but it is not included because it had not passed a Windows build and game test when reviewed.

Source and measured result:
- https://github.com/AntoninMichelq/VIctory-forkAMD
- https://github.com/AntoninMichelq/VIctory-forkAMD/commit/b74ac64da2e289cc632980cf8e508c2d1ba909ac
- https://github.com/AntoninMichelq/VIctory-forkAMD/blob/main/HANDOFF.md
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
