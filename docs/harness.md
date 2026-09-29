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

Project Contract checks require `.agents/project-contract.md`, its five standard sections in order, and each known field inside its owning section. The default `repository` profile validates repository instructions, ticket backend, required default and feature branch policies, workspace preservation, and remote/target delivery fields. The explicit `folder` profile validates project instructions, task tracking, workspace preservation, and a destination without introducing repository-only fields. Both profiles validate typed verification status, safe relative paths, the `yes` preservation and Delivery Gate invariants, and an allowed delivery mode. Work-artifact locations may be a project path, `unconfigured`, or `configured by` an existing relative configuration file. Bootstrap Contracts may truthfully leave bootstrap verification, complete verification, and project checks `unconfigured`. Checks reject misplaced or unknown fields, missing or unsafe references, nonsensical commands, and a contract that claims complete verification while the default project checks declare themselves unconfigured.

Select the folder schema explicitly when validating a plain project folder:

```bash
HARNESS_CONTRACT_PROFILE=folder \
  HARNESS_PROJECT_CONTRACT=/absolute/project/.agents/project-contract.md \
  HARNESS_CONTRACT_ROOT=/absolute/project \
  bash scripts/harness/validate-project-contract.sh
```

## Verification states

The source repository configures checks for its own Skills and Contract, so its verification ends with:

```text
Harness checks: passed
Repository Skills: passed
Project Contract: passed
Contract verification status: complete
Project checks: passed
Overall: verification passed
HARNESS_VERIFICATION_STATUS=complete
```

A derived project should start in bootstrap until its product checks are configured. Its successful bootstrap summary ends with:

```text
Harness checks: passed
Repository Skills: passed
Project Contract: passed
Contract verification status: bootstrap
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
HARNESS_VERIFICATION_STATUS=bootstrap
```

This bootstrap result confirms the reusable base works. It does not claim that the derived project's tests, lint, or build ran.

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

The source repository sets `PROJECT_CHECKS_CONFIGURED=1` and verifies its repository Skills and Project Contract. Because the base cannot know a derived project's language or toolchain, project onboarding must reset that flag to `0` and replace the source checks with the derived project's canonical test, lint, build, or other verification commands. Change it back to `1` only after those commands are configured.

Keep `set -euo pipefail` and do not swallow failures. This allows the original non-zero status to reach `make verify` and CI. The onboarding sequence keeps the Contract honest while checks are being selected and wired; see [Keep the Contract honest](./getting-started.md#3-keep-the-contract-honest).

## CI

`.github/workflows/verify.yml` runs `make verify` on Ubuntu and macOS for pushes and pull requests. Local development and CI therefore use the same entrypoint. The workflow uses read-only repository permissions and does not run the non-deterministic Harness audit.

In a derived project, CI can be green while project checks are not configured. In that bootstrap state it proves only that the base's Harness and Skills pass. Read the job output and finish project setup before treating it as product verification. The source repository itself is configured and emits the complete status shown above.

## Harness audit

`make harness-audit` requires the Codex CLI. It performs an ephemeral, read-only repository review and returns at most three evidence-backed suggestions for durable improvements to `AGENTS.md`, Skills, tests, or verification. It never edits files and should recommend nothing when the evidence does not justify a reusable rule.

## Test and diagnostic overrides

These environment variables support regression tests and controlled diagnostics:

| Variable | Purpose |
| --- | --- |
| `HARNESS_SKILLS_DIR` | Validate a different active Skills directory. |
| `HARNESS_PROJECT_CONTRACT` | Validate a different Project Contract file. |
| `HARNESS_CONTRACT_ROOT` | Resolve a diagnostic contract against another repository root. |
| `HARNESS_CONTRACT_PROFILE` | Select the strict `repository` profile (default) or the strict `folder` profile. |
| `HARNESS_SKIP_TESTS=1` | Skip Harness regression tests inside `verify.sh`. |
| `HARNESS_PROJECT_CHECKS` | Run a different project checks script. An override is treated as configured. |
| `HARNESS_CODEX_BIN` | Select the Codex executable used by the audit. |

These are integration hooks, not replacements for the normal `make verify` entrypoint.
