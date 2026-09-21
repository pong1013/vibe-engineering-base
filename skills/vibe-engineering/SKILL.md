---
name: vibe-engineering
description: Configure or inspect a durable AI engineering Harness in a writable project folder. Use when a user wants to add project instructions, a Project Contract, or evidence-based Harness maintenance to an existing Git or plain folder.
---

# Vibe Engineering

Use this Skill for a selected writable project folder. A chat without a writable folder can receive recommendations, but cannot claim setup or durable changes.

## Setup

1. Resolve the user's current or explicit project folder. Do not substitute the filesystem root, the user's home folder, or a guessed location.
2. Preview setup without writing:

   ```bash
   python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" setup --target /absolute/project/path
   ```

3. Show the target, selected capabilities, and file operations from the JSON preview. Obtain the user's approval immediately before applying the mutation unless that exact setup was already authorized.
4. Apply only the previewed state with its `plan_token`:

   ```bash
   python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" setup --target /absolute/project/path --apply --plan-token TOKEN
   ```

The default capabilities are `harness` and `harness-feedback`. Pass `--capability harness` or `--capability harness-feedback` repeatedly to select a subset. Setup owns only the bounded block it adds to `AGENTS.md`; preserve every other line.

## Status

Inspect without writing:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" status --target /absolute/project/path
```

Report each managed path as `current`, `modified`, or `missing`. Report `upgrade-available` when the installed manifest records a different source version. Do not describe status as installed when the manifest is absent.

Setup and status are implemented now. Do not simulate upgrade or learning by overwriting modified files; those intents require their dedicated workflow support.
