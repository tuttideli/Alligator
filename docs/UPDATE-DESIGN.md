# Update design

The updater will eventually:

1. Read a version manifest from the authenticated private repository.
2. Validate every downloaded file against a SHA-256 digest from the manifest.
3. Stage files before changing the installed runtime.
4. Verify staged files and preserve a timestamped backup.
5. Apply only approved project-owned files.
6. Roll back replaced files if verification or installation fails.
7. Never download or redistribute game files, save data, caches, or memory dumps.

The initial repository only defines the intended contract. Update execution is intentionally disabled until the existing v0.6 scripts and payload format have been reviewed and mapped accurately.
