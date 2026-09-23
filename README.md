# vibe-engineering-base

[English](./README.md) | [繁體中文](./README.zh-TW.md)

A language-agnostic foundation for giving Codex durable project context, repeatable verification, and a way to learn from completed work.

## Choose an entrypoint

### Add it to an existing project

Install the user-scoped `$vibe-engineering` Skill from this repository with the preinstalled `$skill-installer`:

```text
$skill-installer Install the Skill from https://github.com/pong1013/vibe-engineering-base/tree/main/skills/vibe-engineering
```

The installed Skill becomes available on the next turn. Open the writable project folder in Codex, then run:

```text
$vibe-engineering Set up the Harness for this project. Preview every change before applying it.
```

The Skill can target an existing Git repository or a plain folder. It adds project guidance, a Project Contract, and `harness-feedback` without replacing content outside its managed `AGENTS.md` block. For a plain folder it omits Git, CI, branch, commit, and pull request assumptions. Setup, status, upgrade, and evidence-based learning are described in the [Skills guide](./docs/skills.md).

### Start a new project from the template

1. Open the [template repository](https://github.com/pong1013/vibe-engineering-base), select **Use this template**, and create your repository.
2. Clone or open the new repository at its root in Codex.
3. Paste this prompt:

<!-- template-setup-prompt:start -->
```text
Configure this vibe-engineering template as the actual project in the current repository.

First inspect the repository, including its source, package or build configuration, README files, AGENTS.md, .agents/project-contract.md, scripts/harness/project-checks.sh, and existing documentation. Ask me only for consequential facts that cannot be established from the repository; when asking, recommend a concrete default.

Then complete these tasks:
1. Establish the project identity: product name, purpose, intended users, supported platforms, technology stack, and canonical development commands. Replace the template README content with accurate project setup and usage instructions.
2. Replace template-specific durable guidance in AGENTS.md with this project's architecture boundaries, invariants, compatibility constraints, and canonical commands. Keep the general safety and verification rules that still apply.
3. Choose and document the real locations for specifications, tracker instructions, domain language, and architecture decisions. Remove inherited references to pong1013/vibe-engineering-base. If this project has no ticket tracker or domain document, record that honestly as unconfigured; do not invent an integration.
4. Change .agents/project-contract.md to Status: bootstrap while configuring it. Point it at the actual repository guidance and knowledge locations, record the real workspace and delivery policy, and keep complete verification unconfigured until product checks are real.
5. Identify the project's real deterministic test, lint, typecheck, and build commands. Safely update scripts/harness/project-checks.sh to run the applicable commands and preserve their failure exit codes. Set PROJECT_CHECKS_CONFIGURED=1 only when those commands exercise the product. If no meaningful product check exists yet, leave it at 0 and describe the gap.
6. Keep the repository-scoped harness-feedback Skill active unless I explicitly decline project learning. Do not install or modify any Global Workflow configuration.
7. After customization and product-check wiring are finished, update the Project Contract to Status: complete only if its claims are true, then run make verify. Run it at the end, not as the first setup step. Fix failures caused by the configuration and report the final verification result, every changed file, and any remaining bootstrap gaps.
```
<!-- template-setup-prompt:end -->

See [Getting Started](./docs/getting-started.md) for the fallback clone path, expected results, and completion checklist.

## How the Harness fits together

```text
make verify
├── check Harness shell scripts
├── run Harness regression tests
├── validate repository Skills and the Project Contract
└── run the project's own checks
```

The GitHub Actions workflow uses the same `make verify` entrypoint as local development. A configured project reports complete only after real product checks are connected. Until then its Contract remains at `Status: bootstrap`, and verification reports the remaining gap without claiming that product behavior passed.

## Included in `0.1.0`

- `AGENTS.md` for durable project rules that Codex should follow on nearly every change.
- A repeatable Harness with regression tests and macOS/Linux CI for Git repositories.
- `harness-feedback`, an implicit-eligible repository Skill for improving durable guardrails from evidence.
- The user-scoped `$vibe-engineering` Skill source for safe setup, status, upgrades, and evidence-based learning in another project.

## Documentation

- **First use:** [Getting Started](./docs/getting-started.md)
- **Connect tests, lint, and build:** [Harness](./docs/harness.md)
- **Adjust project rules and structure:** [Customization](./docs/customization.md)
- **Install and use Skills:** [Skills](./docs/skills.md)

## Support and license

macOS with Bash 3.2+ and Linux with Bash are supported. Native Windows and WSL are not officially supported in `0.1.0`.

MIT licensed.
