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
    └── run project-checks.sh
```

Skill checks use lightweight shell validation. They verify directory and Skill names, required frontmatter fields, unfinished placeholders, required `agents/openai.yaml` interface fields, default prompts, and the shape of optional invocation policies. They do not fully parse or validate arbitrary YAML.

## Verification states

An uncustomized base exits successfully and ends with:

```text
Harness checks: passed
Repository Skills: passed
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
```

This confirms the reusable base works. It does not claim that product tests, lint, or build ran.

After `PROJECT_CHECKS_CONFIGURED=1` and every configured command succeeds, the final two lines become:

```text
Project checks: passed
Overall: verification passed
```

If a Harness, Skill, or project check fails, `verify.sh` stops and preserves the non-zero exit status. It does not print a misleading success summary.

## Commands

```bash
make verify         # Harness syntax, tests, repository Skills, and project checks
make test           # Harness regression tests only
make harness-audit  # Read-only Codex audit for durable Harness improvements
```

Run `make verify` after changing code, project guidance, Skills, checks, or Harness behavior.

## Configure project checks

The base cannot know a derived project's language or toolchain, so `scripts/harness/project-checks.sh` starts with `PROJECT_CHECKS_CONFIGURED=0` and no product commands. Change it to `1` only after adding the project's canonical test, lint, build, or other verification commands.

Keep `set -euo pipefail` and do not swallow failures. This allows the original non-zero status to reach `make verify` and CI. Copyable Node.js and Python examples are in [Getting Started](./getting-started.md#4-connect-project-checks).

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
| `HARNESS_SKIP_TESTS=1` | Skip Harness regression tests inside `verify.sh`. |
| `HARNESS_PROJECT_CHECKS` | Run a different project checks script. An override is treated as configured. |
| `HARNESS_CODEX_BIN` | Select the Codex executable used by the audit. |

These are integration hooks, not replacements for the normal `make verify` entrypoint.
