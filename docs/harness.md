# Harness

[English](./harness.md) | [繁體中文](./harness.zh-TW.md) | [Back to README](../README.md)

This reference explains how verification works and what each status means. The Harness turns project rules into repeatable, machine-checkable commands.

`scripts/harness/` is an ordinary scripts directory. Codex knows to use it because `AGENTS.md`, the Makefile, and CI point to the same entrypoint.

## Verification flow

```text
make verify
└── scripts/harness/verify.sh
    ├── check Bash syntax in Harness and test scripts
    ├── run Harness regression tests
    ├── validate active repository Skills
    ├── validate the Project Contract
    └── run project-checks.sh
```

Skill checks use lightweight shell validation. They verify directory and Skill names, required frontmatter fields, unfinished placeholders, required `agents/openai.yaml` interface fields, default prompts, and the shape of optional invocation policies. They do not fully parse or validate arbitrary YAML.

Project Contract checks require `.agents/project-contract.md`, its five standard sections in order, and each known field inside its owning section. They validate typed verification status, safe repository-relative paths, the `yes` preservation and Delivery Gate invariants, and an allowed delivery mode. They reject misplaced or unknown fields, nonsensical commands, and a contract that claims complete verification while the default project checks declare themselves unconfigured.

## Verification states

An uncustomized base exits successfully and ends with:

```text
Harness checks: passed
Repository Skills: passed
Project Contract: passed
Contract verification status: bootstrap
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
HARNESS_VERIFICATION_STATUS=bootstrap
```

This confirms the reusable base works. It does not claim that product tests, lint, or build ran.

After `PROJECT_CHECKS_CONFIGURED=1`, Contract status is complete, and every configured command succeeds, the summary ends with:

```text
Contract verification status: complete
Project checks: passed
Overall: verification passed
HARNESS_VERIFICATION_STATUS=complete
```

The final machine status is complete only when both the Contract status and project-check state are complete. A successful checks override paired with a bootstrap Contract still emits `HARNESS_VERIFICATION_STATUS=bootstrap`. If a Harness, Skill, or project check fails, `verify.sh` stops and preserves the non-zero exit status.

## Commands

```bash
make verify         # Harness syntax, tests, Skills, Project Contract, and project checks
make test           # Harness regression tests only
make harness-audit  # Read-only Codex audit for durable Harness improvements
```

Run `make verify` after changing code, project guidance, Skills, checks, or Harness behavior.

## Configure project checks

The base cannot know a derived project's language or toolchain, so `scripts/harness/project-checks.sh` starts with `PROJECT_CHECKS_CONFIGURED=0` and no product commands. Change it to `1` only after adding the project's canonical test, lint, build, or other verification commands.

Keep `set -euo pipefail` and do not swallow failures. This allows the original non-zero status to reach `make verify` and CI. Copyable Node.js and Python examples are in [Getting Started](./getting-started.md#5-connect-product-checks).

## CI

`.github/workflows/verify.yml` runs `make verify` on Ubuntu and macOS for pushes and pull requests. Local development and CI therefore use the same entrypoint. The workflow uses read-only repository permissions and does not run the non-deterministic Harness audit.

CI can be green while project checks are not configured. In that state it proves only that the base's Harness and Skills pass. Read the job output and finish project setup before treating it as product verification.

## Harness audit

`make harness-audit` requires the Codex CLI. It performs an ephemeral, read-only repository review and returns at most three evidence-backed suggestions for durable improvements to `AGENTS.md`, Skills, tests, or verification. It never edits files and should recommend nothing when the evidence does not justify a reusable rule.

## Test and diagnostic overrides

These environment variables support regression tests and controlled diagnostics:

| Variable | Purpose |
| --- | --- |
| `HARNESS_SKILLS_DIR` | Validate a different active Skills directory. |
| `HARNESS_PROJECT_CONTRACT` | Validate a different Project Contract file. |
| `HARNESS_CONTRACT_ROOT` | Resolve a diagnostic contract against another repository root. |
| `HARNESS_SKIP_TESTS=1` | Skip Harness regression tests inside `verify.sh`. |
| `HARNESS_PROJECT_CHECKS` | Run a different project checks script. An override is treated as configured. |
| `HARNESS_CODEX_BIN` | Select the Codex executable used by the audit. |

These are integration hooks, not replacements for the normal `make verify` entrypoint.
