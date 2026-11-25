# Alligator

Alligator is the public Windows launcher and maintenance workspace for a local DexNom Ultra / VIctory installation.

It keeps orchestration, profile selection, diagnostics and self-update logic separate from the game and the renderer source. The renderer source and game stay on the user's PC.

## What works now

- `Alligator.ps1`: PowerShell 5.1 entry point for Launch, Build, Doctor, Profiles, Rollback, Report, Collect and Update.
- `Start-Alligator.cmd`: double-click entry point for the normal launch.
- `updater/Update.ps1`: fast-forward-only Git self-update for a clean Alligator checkout. It updates this repository only; it does **not** update the VIctory engine.
- Example local config at `config/settings.example.json`. The real `config/settings.json` is local and ignored by Git.
- CI parses PowerShell scripts and JSON on Windows and rejects tracked game/runtime binaries and local data.

## One-time setup

1. Install Git for Windows, Rust for Windows and Visual Studio Build Tools with the Desktop development with C++ workload, x64 MSVC tools and Windows 10/11 SDK.
2. Clone this repository:
   ```powershell
   cd "$env:USERPROFILE\\Downloads"
   git clone https://github.com/tuttideli/Alligator.git
   cd .\\Alligator
   ```
3. Run `.Alligator.ps1 -Action Doctor` once. On first run, Alligator copies the example configuration to `config/settings.json`.
4. Edit `config/settings.json` and set `gameExecutable` to the full path of your own `game_scarlett_master.exe`. Confirm `engineSourceDirectory` points to the existing v0.6 source folder.
5. Use `.Start-Alligator.cmd` or `.Alligator.ps1`.

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

The default profile is `UltraSafe1080`: it avoids the v0.6 material-demand and long texture-bake experiments. It is a controlled starting point, not a promise of high FPS. `Display720` only changes the title display mode; it does not guarantee a lower internal render resolution.

## Important separation

- Alligator self-updates from this Git repository.
- The current v0.6 renderer is built and installed using the original `ultra/Build-Ultra.ps1` from the external engine source directory.
- Alligator's `Build` and `Rollback` actions call those original scripts. They do not replace or rewrite renderer code.
- Renderer upgrades from other VIctory forks are separate engine changes. They must be ported/tested with source attribution and the applicable GPL terms before they are treated as a stable release.

## Repository safety

Do not commit game files, game executables, saves, shader caches, runtime caches, memory dumps, personal diagnostic logs, access tokens or credentials. Review reports before sharing because diagnostic logs can contain local paths and account folder names.

## Current renderer baseline

The user's local DexNom Ultra v0.6 source update was already applied and built successfully on 2026-11-25. The game has been observed to render at about 0.7–0.8 FPS with a HUD count of roughly 3,455 draws per frame without a ready host pipeline. This is evidence of serious renderer pipeline coverage/creation issues; it is not just a launcher setting.

Alligator does not yet deliver a renderer fix or claim to make the game playable. Collect the post-game report before selecting a code change.

## Research

See:
- `docs/RESEARCH-AND-PERFORMANCE.md`
- `docs/DIAGNOSTICS.md`
- `docs/PROFILE-GUIDE.md`
- `docs/UPDATE-DESIGN.md`
