---
name: vibe-engineering
description: Configure, inspect, or safely upgrade a durable AI engineering Harness in a writable project folder. Use when a user wants to add or update project instructions, a Project Contract, or evidence-based Harness maintenance in an existing Git or plain folder.
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

## Upgrade

Preview an upgrade without writing:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" upgrade --target /absolute/project/path
```

Show every `addition`, `replacement`, `unchanged`, and `conflict` operation. A modified managed file remains a conflict and includes a reviewable diff. Do not apply while conflicts are unresolved.

When the user explicitly decides to replace one conflicted file with the packaged version, bind that exact decision into a new preview:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" upgrade --target /absolute/project/path --resolve-conflict .agents/project-contract.md
```

Apply the approved preview with the same resolution arguments and its `plan_token`:

```bash
python3 "${CODEX_HOME:-$HOME/.codex}/skills/vibe-engineering/scripts/project_manager.py" upgrade --target /absolute/project/path --resolve-conflict .agents/project-contract.md --apply --plan-token TOKEN
```

Each `--resolve-conflict` decision means replace that path with the packaged content. Repeat the option for multiple reviewed conflicts. The command rejects stale tokens, extra or duplicate decisions, unsafe paths, and wrong-type conflicts. Upgrade commits its manifest last and rolls back all managed writes if a write fails.

Setup, status, and upgrade are implemented now. Do not simulate learning; that intent requires its dedicated workflow support.
