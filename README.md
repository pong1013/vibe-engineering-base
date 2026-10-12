# vibe-engineering-base

[English](./README.md) | [繁體中文](./README.zh-TW.md)

A language-agnostic foundation for giving Codex durable project context, repeatable verification, and a way to learn from completed work.

## Choose an entrypoint

### Add it to an existing project

Choose this path if you already have a project and want Codex to remember its rules, run repeatable checks, and turn useful lessons into project guidance. It works in a Git repository or a plain folder. Your existing project stays the starting point; you do not need to copy this template into it.

**What changes?** Before setup, Codex has to rediscover your project's rules and checks from the current conversation and files. After setup, the project has durable `AGENTS.md` guidance, a Project Contract pointing to its real commands and knowledge, and a `harness-feedback` Skill for learning from completed work. The user-scoped `$vibe-engineering` Skill can later report installation status, preview upgrades, and propose reusable project Skills from evidence. Installing the Skill alone does not edit the project; setup shows the proposed changes before writing them.

1. **Install the helper Skill.** In Codex, use the preinstalled `$skill-installer` to make `$vibe-engineering` available to your account:

   ```text
   $skill-installer Install the Skill from https://github.com/pong1013/vibe-engineering-base/tree/main/skills/vibe-engineering
   ```

2. **Open the project you want to improve.** Open its writable folder in Codex. The Skill becomes available on the next turn; opening the target folder tells it where to propose the setup.

3. **Ask for a preview of the setup.** This shows the files and changes before you decide to apply them:

   ```text
   $vibe-engineering Set up the Harness for this project. Preview every change before applying it.
   ```

Setup preserves content outside its managed `AGENTS.md` block. For a plain folder it omits Git, CI, branch, commit, and pull request assumptions. Setup, status, upgrade, and evidence-based learning are described in the [Skills guide](./docs/skills.md).

### Start a new project from the template

Choose this path if you are starting a **new Git repository** and want project guidance, verification, and CI in place from the beginning. It suits someone ready to describe what they are building and to connect real tests or other product checks. If the product does not have checks yet, the setup records that gap and leaves verification in bootstrap status.

1. **Create your own repository.** Open the [template repository](https://github.com/pong1013/vibe-engineering-base), select **Use this template**, and create a repository under your account or organization. This gives your project its own copy of the starter files.
2. **Open that copy in Codex.** Clone or open the new repository at its root so Codex can inspect the files it needs to customize.
3. **Give Codex the setup prompt below.** It turns the starter files into guidance and checks for your actual project. It asks for important details it cannot infer, then runs `make verify` after customization.

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
