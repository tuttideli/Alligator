# Alligator

Private project workspace for the DexNom Ultra launcher and updater.

## Purpose

Alligator is the maintenance and update-control project for the local DexNom Ultra installation. It is intended to simplify version checks, safe updates, backups, and launch workflows on Windows.

## Repository safety

- Do not commit GTA game files, game executables, save files, shader caches, runtime caches, memory dumps, or personal diagnostic logs.
- Do not commit access tokens, credentials, private keys, or machine-specific secrets.
- Keep upstream VIctory code and third-party components clearly identified with their original licenses and provenance.
- Do not ship generated binaries until their source, licensing, integrity, and compatibility have been reviewed.

## Planned layout

- `launcher/`: PowerShell entry point and launch orchestration.
- `updater/`: version manifest, integrity checks, staged updates, and rollback.
- `config/`: example configuration only; machine-specific settings remain local.
- `docs/`: setup, maintenance, and troubleshooting notes.
- `releases/`: release metadata and small, approved project-owned assets only.

## Current baseline

The local DexNom Ultra v0.6 source update was reported as already applied, and its build completed successfully on 2026-11-25. This repository has not yet been connected to that local checkout. No launcher or updater implementation is considered production-ready yet.
