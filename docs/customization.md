# Customization

[English](./customization.md) | [繁體中文](./customization.zh-TW.md) | [Back to README](../README.md)

This is the reference manual for adapting each part of the base. For the setup sequence and copyable project-check examples, start with [Getting Started](./getting-started.md).

Customize the base so its guidance and checks describe the derived project rather than `vibe-engineering-base`. Keep instructions that Codex reads on every task small, and move details to the narrowest appropriate location.

## `AGENTS.md`

Keep rules that should affect nearly every repository task:

- Canonical setup, test, and build entrypoints.
- High-level architecture boundaries and invariants.
- Compatibility and safety constraints.
- Expectations for verification and documentation.

Replace the `Project-specific guidance` placeholder. Do not copy detailed architecture, task playbooks, or rules already enforced by tools into this file.

## Deterministic project checks

Edit `scripts/harness/project-checks.sh` so `make verify` runs the derived project's real checks. Prefer one canonical command per concern and preserve non-zero exit statuses. Keep formatting, lint, type, test, and build rules in tools when a machine can enforce them.

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
| Repeatable task-specific workflows | `.agents/skills/` |
| Machine-checkable behavior | Tests, linters, and verification scripts |
| Canonical domain vocabulary | `CONTEXT.md` when the project uses it |
| Durable, non-obvious architecture decisions | `docs/adr/` |
| Architecture explanations and runbooks | Project documentation |
| External system access | MCP server or connector |

## CI and platform support

The included workflow verifies the repository on Ubuntu and macOS. Adjust the matrix only when the project's supported platforms change, and keep local and CI entrypoints aligned.

Native Windows and WSL are not officially supported by base version `0.1.0`.

## Base updates

Version `0.1.0` has no installer, automatic merge, or upgrade mechanism for existing repositories. After customization, the derived repository owns its copies of `AGENTS.md`, Skills, scripts, tests, and workflows. Review later base changes manually instead of overwriting project-specific files.

Requirements for a future conflict-safe installer are tracked in [`TODO.md`](../TODO.md).
