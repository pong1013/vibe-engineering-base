# TODO

## Available in `0.1.0`

The project now has two entrypoints:

- Use the GitHub Template to start a new Git repository, then give Codex the README's setup prompt.
- Install the user-scoped `$vibe-engineering` Skill from `skills/vibe-engineering` with `$skill-installer` to configure an existing Git repository or writable plain folder.

`$vibe-engineering` supports setup, read-only status, conflict-safe upgrade, and evidence-based learn intents. Setup and upgrade preview changes, bind apply operations to the target and current file state, track managed files and checksums in a versioned manifest, preserve content outside the managed `AGENTS.md` block, and roll back failed writes. Plain folders omit Git, CI, branch, commit, and pull request assumptions.

## Future candidates

- Publish tagged Skill releases and add remote release discovery. Upgrade currently compares a target manifest with the locally installed Skill package; it does not fetch or select a newer release.
- Add opt-in managed capabilities for more project tooling only after their ownership and cross-platform conflict behavior are specified. The current setup scope is project guidance, the Project Contract, and `harness-feedback`.
- Consider guided three-way conflict assistance while keeping explicit user review and atomic writes. The current upgrade safely leaves locally modified managed files unresolved until the user chooses a bounded replacement.
- Add native Windows or WSL support after equivalent path-safety, atomic-write, and regression coverage exists.
