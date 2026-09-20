# Project Contract

This file is the workflow-facing index for this repository. Follow `AGENTS.md` and executable tooling when they conflict with this contract, then update this file only after the conflict is resolved.

## Verification

- Status: bootstrap
- Bootstrap verification: `make verify`
- Complete verification: unconfigured
- Project checks: `scripts/harness/project-checks.sh`

## Knowledge

- Repository instructions: `AGENTS.md`
- Domain language: `CONTEXT.md`
- Architecture decisions: `docs/adr/`

## Work artifacts

- Specifications: configured by `docs/agents/issue-tracker.md`
- Ticket backend: configured by `docs/agents/issue-tracker.md`

## Workspace

- Default branch: discover from the repository
- Feature branch naming: follow an explicit repository policy; otherwise propose a safe name
- Preserve unrelated working-tree changes: yes

## Delivery

- Mode: unconfigured
- Remote and target branch: discover and confirm before delivery
- Require Delivery Gate: yes
