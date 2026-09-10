# TODO

## Existing-repository installer

Do not implement an installer until its merge and upgrade behavior is specified and tested. A future version should meet all of these requirements:

- Support an explicit target repository and a dry-run mode.
- Resolve and validate the exact target; reject `/`, a user home directory, non-Git directories, and uncertain paths.
- Show every planned addition, unchanged file, and conflict before writing.
- Treat identical existing files as unchanged.
- Refuse the entire operation when any destination file differs or has the wrong type.
- Make zero writes on conflict or failed preflight checks; do not leave a partial installation.
- Never overwrite or automatically merge an existing `AGENTS.md`, active Skill, Makefile, README, license, or workflow.
- Preserve executable permissions on installed scripts.
- Support a pinned base version and document the update strategy for customized files.
- Add macOS and Linux regression tests for clean install, repeat install, dry run, target validation, and conflicts.

Version `0.1.0` intentionally provides no `install.sh`, curl installer, force flag, or automatic upgrade path.
