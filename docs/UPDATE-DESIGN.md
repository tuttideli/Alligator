# Update design

Alligator is a public GitHub repository. The self-updater follows its configured Git remote and branch using fast-forward-only updates.

The current updater updates the Alligator scripts and documentation only. It does not update or overwrite the DexNom/VIctory engine or game files.

A future engine update channel must:
1. Pin a reviewed upstream/fork commit rather than blindly tracking a moving branch.
2. Verify the applicable license and preserve author attribution and source history.
3. Stage files before changing an installed runtime.
4. Verify every staged file against a SHA-256 manifest.
5. Preserve a timestamped backup.
6. Apply only engine files from the reviewed commit.
7. Roll back replaced files if verification or installation fails.
8. Keep game files, saves, caches, logs, and memory dumps outside the repository.

The AMD experiment currently clones and checks out a reviewed commit in a separate local folder. It builds and runs from that checkout without touching the existing v0.6 installation.
