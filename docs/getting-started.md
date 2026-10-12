# Getting Started

[English](./getting-started.md) | [繁體中文](./getting-started.zh-TW.md) | [Back to README](../README.md)

Use the user-scoped `$vibe-engineering` Skill to add the system to an existing project. Use the GitHub Template to start a new Git repository. The [README](../README.md#choose-an-entrypoint) gives copyable instructions for both paths.

## Requirements

- Codex Desktop, CLI, or IDE extension.
- macOS with Bash 3.2+ or Linux with Bash.
- Git only for the template path or an existing Git repository.

The Harness does not require a particular application language, package manager, framework, ticket tracker, or domain documentation layout.

## Existing project

Install `skills/vibe-engineering` with `$skill-installer`, then invoke `$vibe-engineering` in the target folder. Setup always produces a preview before writing. It preserves content outside its managed `AGENTS.md` block and records managed files and checksums in `.agents/vibe-engineering/manifest.json`.

Git repositories receive Git-aware guidance. Plain folders receive the same durable instructions, Contract, and project-learning Skill without Git, CI, branch, commit, or pull request assumptions. See the [Skills guide](./skills.md#user-scoped-vibe-engineering) for setup, status, upgrade, and learn behavior.

## New project from the template

### 1. Create your repository

Open the [template repository](https://github.com/pong1013/vibe-engineering-base), select **Use this template**, and create a repository under your account or organization. Clone it, then open its root in Codex.

If the template button is unavailable, use a normal clone and detach it from the source:

```bash
git clone https://github.com/pong1013/vibe-engineering-base.git my-project
cd my-project
git remote remove origin
```

Create the destination repository and add it as `origin` before delivery. Do not push a derived project to the source remote.

### 2. Give Codex the setup prompt

Paste the complete prompt from [Start a new project from the template](../README.md#start-a-new-project-from-the-template). It directs Codex to inspect the repository first, ask only for consequential missing facts, and configure the following as one setup task:

- project identity and product README;
- durable `AGENTS.md` guidance;
- specification, tracker, domain, and ADR entrypoints;
- a bootstrap Project Contract with the project's real workspace and delivery policy;
- real product tests, lint, typecheck, and build commands;
- repository learning through `harness-feedback`.

The copied source files contain references used to maintain `vibe-engineering-base`, including the source tracker identity. The setup must replace those references with the new project's information or mark them unconfigured. It must not publish work to `pong1013/vibe-engineering-base`.

Global Workflow is a separate user-scoped capability. This template neither installs nor modifies it, and it is not required to configure the project.

### 3. Keep the Contract honest

During setup, use these verification values:

```text
- Status: bootstrap
- Bootstrap verification: `make verify`
- Complete verification: unconfigured
```

Keep `PROJECT_CHECKS_CONFIGURED=0` while `scripts/harness/project-checks.sh` has no meaningful product commands. Unknown tracker, domain, branch, and delivery values should remain unconfigured rather than being guessed.

Once real checks are connected, set `PROJECT_CHECKS_CONFIGURED=1`, change the Contract to `Status: complete`, and set Complete verification to `make verify`. The Contract is a thin index; architecture explanations belong in project documentation.

The [Harness reference](./harness.md#configure-project-checks) explains how to connect product checks without hiding command failures.

### 4. Verify at the end

After the repository describes the actual project and product checks are wired, run:

```bash
make verify
```

A fully configured project ends with `Project checks: passed`, `Overall: verification passed`, and `HARNESS_VERIFICATION_STATUS=complete`.

If meaningful product checks do not exist yet, leave the Contract at bootstrap. Verification may confirm the Harness itself, but the final report must list the missing checks and must not claim complete product verification.

## Completion checklist

- [ ] The product README replaces the template landing page.
- [ ] `AGENTS.md` describes actual architecture boundaries, invariants, and canonical commands.
- [ ] Source repository and tracker identities have been removed or replaced.
- [ ] `.agents/project-contract.md` points to real commands, locations, and policies.
- [ ] `PROJECT_CHECKS_CONFIGURED=1` only when product checks run real commands.
- [ ] Repository Skills have been reviewed and `harness-feedback` remains active unless deliberately removed.
- [ ] Final `make verify` reports complete verification, or remaining bootstrap gaps are explicit.
- [ ] Git CI uses the same `make verify` entrypoint when CI is part of the project.
