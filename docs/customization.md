# Customization

[English](./customization.md) | [繁體中文](./customization.zh-TW.md) | [Back to README](../README.md)

This is the reference manual for adapting each part of the base. For the setup sequence and copyable project-check examples, start with [Getting Started](./getting-started.md).

Customize the base so its guidance and checks describe the derived project rather than `vibe-engineering-base`. Keep instructions that Codex reads on every task small, and move details to the narrowest appropriate location.

## Project Contract

`.agents/project-contract.md` is the stable entrypoint for repository-aware workflows. Keep its five sections in order: Verification, Knowledge, Work artifacts, Workspace, and Delivery.

- Point to authoritative commands and files instead of copying their contents.
- Keep Verification at `Status: bootstrap` with `Complete verification: unconfigured` until real project checks exist. After configuring them, set `Status: complete` and name the complete command.
- Configure the ticket backend and delivery mode when the project chooses them.
- Keep fields unconfigured when no policy exists; do not invent one from incidental history.
- Treat `AGENTS.md` and executable tooling as authoritative when they conflict with the contract, then update the contract after resolving the conflict.
- Run `make verify` after changing the contract.

## `AGENTS.md`

Keep rules that should affect nearly every repository task:

- Canonical setup, test, and build entrypoints.
- High-level architecture boundaries and invariants.
- Compatibility and safety constraints.
- Expectations for verification and documentation.

Replace the `Project-specific guidance` placeholder. Do not copy detailed architecture, task playbooks, or rules already enforced by tools into this file.

## Deterministic project checks

Edit `scripts/harness/project-checks.sh` so `make verify` runs the derived project's real checks. Prefer one canonical command per concern and preserve non-zero exit statuses. Keep formatting, lint, type, test, and build rules in tools when a machine can enforce them.

After setting `PROJECT_CHECKS_CONFIGURED=1`, update the Project Contract to `Status: complete` and set the Complete verification value to `make verify`. The validator rejects a complete contract that still points to an explicitly unconfigured default project-checks script.

## Repository Skills

Keep a Skill when its workflow should be available to everyone working in the repository. Remove a bundled Skill if that workflow is not part of the project. Add a Skill only when it has a distinct trigger and reusable instructions that cannot be discovered cheaply from the code.

For each active Skill:

- Match the folder name to the `name` in `SKILL.md`.
- Write a narrow `description` that distinguishes when the workflow applies.
- Add `agents/openai.yaml` with UI metadata and a default prompt that mentions `$skill-name`.
- Set `policy.allow_implicit_invocation` deliberately. Use `false` for workflows that should run only when named.
- Put conditional detail in references and repeated deterministic behavior in scripts.

Use `examples/project-skill/` as a starting point, not as an active Skill.

## Project documentation

Replace the root README with the product's own landing page and setup instructions. Keep or adapt the guides under `docs/` according to the project's needs.

Route knowledge by purpose:

| Knowledge | Location |
| --- | --- |
| Rules for nearly every task | `AGENTS.md` |
| Workflow-facing commands, locations, and policies | `.agents/project-contract.md` |
| Repeatable task-specific workflows | `.agents/skills/` |
| Machine-checkable behavior | Tests, linters, and verification scripts |
| Canonical domain vocabulary | `CONTEXT.md` when the project uses it |
| Durable, non-obvious architecture decisions | `docs/adr/` |
| Architecture explanations and runbooks | Project documentation |
| External system access | MCP server or connector |

## CI and platform support

The included workflow verifies the repository on Ubuntu and macOS. Adjust the matrix only when the project's supported platforms change, and keep local and CI entrypoints aligned.

Native Windows and WSL are not officially supported by base version `0.1.0`.

## Existing-project setup and updates

Install the user-scoped Skill from `skills/vibe-engineering` with `$skill-installer`, then use `$vibe-engineering` in the selected writable project folder. It supports setup, read-only status, conflict-safe upgrade, and evidence-based learn intents. The [Skills guide](./skills.md#user-scoped-vibe-engineering) provides the installation prompt and behavior of each intent.

Setup and upgrade preview their operations before writing. The manifest at `.agents/vibe-engineering/manifest.json` records the installed source version, selected capabilities, managed paths, and checksums. Upgrade can replace an unchanged managed file; a locally modified managed file remains a conflict until the user reviews and explicitly selects that replacement. A stale preview or failed validation does not leave a partial update.

Files outside the managed set, content outside the bounded `AGENTS.md` block, and project-created Skills remain project-owned. Review changes to those files as ordinary project changes rather than expecting the Skill to merge or overwrite them.
