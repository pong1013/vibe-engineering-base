# Getting Started

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [Back to README](../README.md)

This step-by-step tutorial turns `vibe-engineering-base` into a project-specific repository and introduces the recommended development flow.

## Prerequisites

- Git.
- Codex Desktop, CLI, or IDE extension.
- macOS with Bash 3.2+ or Linux with Bash.

The base does not impose an application language, package manager, or framework.

## 1. Create the repository

The recommended path is to open the [template repository](https://github.com/pong1013/vibe-engineering-base), select **Use this template**, and create a new repository. Clone or open the result locally, then start Codex at its root so Codex can discover `AGENTS.md` and `.agents/skills/`.

If the template button is unavailable, use this alternative:

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

Create the destination repository before adding the new project's remote.

## 2. Confirm the bootstrap

Run:

```bash
make verify
```

The initial result reports that the Harness and repository Skills pass while project checks are not configured. This is intentionally a successful bootstrap state. It proves the template works, but it does not claim that product tests, lint, or build ran.

## 3. Add project identity and rules

Replace the root README files with the product's actual introduction and setup instructions. Then replace the `Project-specific guidance` section in `AGENTS.md` with the architecture boundaries, canonical commands, compatibility requirements, and invariants that apply to nearly every change.

For every available setting and where it belongs, use the [Customization reference](./customization.md).

## 4. Connect project checks

The initial `scripts/harness/project-checks.sh` contains the following disabled state:

```bash
PROJECT_CHECKS_CONFIGURED=0

if [[ "${PROJECT_CHECKS_CONFIGURED}" != "1" ]]; then
  echo "WARNING: project checks are not configured. Edit scripts/harness/project-checks.sh." >&2
  exit 0
fi
```

Replace the placeholder section with the real commands and set the flag to `1`. For a Node.js project, a complete small version could be:

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

npm run lint
npm test
npm run build
```

For a Python project, it could be:

```bash
#!/usr/bin/env bash

set -euo pipefail

PROJECT_CHECKS_CONFIGURED=1

python -m ruff check .
python -m pytest
```

Use the repository's canonical commands rather than copying tools it does not use. Keep `set -euo pipefail`: the first failing command then preserves its non-zero result, so `make verify` and CI fail visibly.

The [Harness reference](./harness.md) explains each verification state, CI behavior, and diagnostic override.

## 5. Review Skills and finish setup

Read the [Skills guide](./skills.md). Keep, adapt, or remove bundled Skills deliberately. Then run `make verify` again and confirm the summary now says `Project checks: passed` and `Overall: verification passed`.

Use this checklist before committing the customized base:

- [ ] Product README replaces the template landing page.
- [ ] `AGENTS.md` describes real project rules and canonical commands.
- [ ] `PROJECT_CHECKS_CONFIGURED=1` and project checks run real commands.
- [ ] Bundled Skills have been reviewed for this project's workflow.
- [ ] `make verify` reports complete verification locally.
- [ ] CI runs the same `make verify` entrypoint.

## Recommended development flow

Choose the lightest workflow that fits the uncertainty and risk of the change.

```text
Is the request clear and low-risk?
├── Yes → Ask Codex to implement it and verify the result.
└── No, or the change is important
    └── Invoke $grill-with-docs
        ├── Codex inspects facts available in the repository
        ├── Codex asks one decision question with a recommendation
        ├── You confirm or correct the decision
        ├── Durable terminology and qualifying ADRs are recorded
        └── Continue until the important branches are settled
```

Use `$grill-with-docs` for a new product direction, a substantial feature, unclear domain language, or a consequential architecture choice. Skip it for a small bug or another routine change whose outcome is already precise.

After grilling, stay in the same conversation so unwritten decisions remain available. Ask Codex:

```text
Based on the decisions we just settled, write a reviewable implementation plan. Do not implement it yet.
```

Review that plan before requesting implementation. Version `0.1.0` does not yet bundle `to-spec`, `to-tickets`, or the rest of a full development Skill chain.

## FAQ

### Why does `make verify` warn but exit successfully at first?

The warning marks an intentional bootstrap state. The base can validate its own Harness and Skills before it knows the derived project's language or commands.

### Why is CI green when no product tests ran?

CI is preconfigured to run `make verify`, but the initial project checks are empty. A green run only proves the base is healthy until you configure `project-checks.sh`; afterward it also represents the product checks you added.

### Should I use `$grill-with-docs` for the first feature?

Use it when important behavior, terminology, or trade-offs are unsettled. Example:

```text
$grill-with-docs I want to add team invitations. Inspect the repository, then help me settle the user flow, terminology, authorization boundaries, and important failure cases before implementation.
```
