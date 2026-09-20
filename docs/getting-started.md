# Getting Started

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [Back to README](../README.md)

This tutorial turns `vibe-engineering-base` into an independently understandable and verifiable project for Codex.

## Prerequisites

- Git.
- Codex Desktop, CLI, or IDE extension.
- macOS with Bash 3.2+ or Linux with Bash.

The base does not impose an application language, package manager, or framework.

## 1. Create the repository

Open the [template repository](https://github.com/pong1013/vibe-engineering-base), select **Use this template**, and create a new repository. Clone or open it in Codex at the repository root.

If the template button is unavailable:

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

Create the destination repository before adding its remote.

## 2. Confirm the bootstrap

Run:

```bash
make verify
```

The initial result reports that the Harness, repository Skills, and Project Contract pass while product checks are not configured. This proves the template works; it does not claim that product tests, lint, or build ran.

It also emits `HARNESS_VERIFICATION_STATUS=bootstrap`. Workflow controllers must treat that value as incomplete even though the bootstrap self-check exits successfully.

## 3. Add project identity and durable rules

Replace the root README files with the product's introduction and setup instructions. Replace `AGENTS.md`'s `Project-specific guidance` with architecture boundaries, canonical commands, compatibility requirements, and invariants that apply to nearly every change.

## 4. Configure the Project Contract

Edit `.agents/project-contract.md`:

- Keep `Status: bootstrap`, set Bootstrap verification to `make verify`, and keep `Complete verification: unconfigured` until product checks are connected.
- Point Knowledge entries at the repository's actual instructions, domain language, and ADR locations.
- Choose where specifications live and configure a ticket backend when one exists.
- Record workspace or branch naming only when the project has a real policy.
- Select `none`, `commit-only`, `push`, `pull-request`, or `merge-request` as the delivery mode.

Keep unknown values unconfigured until they are settled. The contract is a thin index, not a second architecture document.

If you use the separately installed `$ai-workflow`, first set the new repository's Git remote and run `$setup-matt-pocock-skills` in that repository. Review its preview and confirm the setup so `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and the Agent skills block name **your** repository. The template's tracker identity belongs to `pong1013/vibe-engineering-base`; do not use it to publish issues for a derived project. After setup, point both Work artifacts fields at the generated tracker file:

```text
- Specifications: configured by `docs/agents/issue-tracker.md`
- Ticket backend: configured by `docs/agents/issue-tracker.md`
```

Keep the Contract at `Status: bootstrap` until the product checks in the next step are configured. `$ai-workflow` cannot publish tickets or implement a feature while verification remains bootstrap.

## 5. Connect product checks

Edit `scripts/harness/project-checks.sh`, replace the disabled section with real commands, and set `PROJECT_CHECKS_CONFIGURED=1`.

Node.js example:

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

npm run lint
npm test
npm run build
```

Python example:

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

python -m ruff check .
python -m pytest
```

Use the repository's canonical tools and preserve non-zero exit statuses. See the [Harness reference](./harness.md).

Now change the Project Contract to `Status: complete` and set Complete verification to `make verify`. A controller may enter Delivery only in this state.

## 6. Review repository Skills

Read the [Skills guide](./skills.md). Keep `harness-feedback` when the project should learn from concrete development evidence. Remove it when that workflow is not part of the project. Create another repository Skill only for repeatable project-specific judgment.

Run `make verify` again. A fully configured project should end with `Project checks: passed` and `Overall: verification passed`.

## Completion checklist

- [ ] Product README replaces the template landing page.
- [ ] `AGENTS.md` describes actual project rules.
- [ ] `.agents/project-contract.md` points to real commands, locations, and policies.
- [ ] `PROJECT_CHECKS_CONFIGURED=1` and product checks run real commands.
- [ ] Repository Skills have been reviewed.
- [ ] `make verify` reports complete verification locally.
- [ ] CI runs the same `make verify` entrypoint.
