# vibe-engineering-base

[English](./README.md) | [繁體中文](./README.zh-TW.md)

A language-agnostic project template for reliable AI-assisted and vibe coding with Codex.

## Quick Start

1. Open the [vibe-engineering-base repository](https://github.com/pong1013/vibe-engineering-base) and select **Use this template**.
2. Clone or open the new repository in Codex.
3. Run the shared verification entrypoint:

   ```bash
   make verify
   ```

4. Ask Codex: `Read AGENTS.md and help me configure the project rules and project checks for this repository.`

In this source repository, the run succeeds with a complete summary because the base's own repository checks are configured:

```text
Harness checks: passed
Repository Skills: passed
Project checks: passed
Overall: verification passed
```

That complete result applies to the source repository only. A project created from the template should use a bootstrap Contract and `PROJECT_CHECKS_CONFIGURED=0` until its own tests, lint, build, and other product checks are connected. During that bootstrap period, `make verify` succeeds but reports `Overall: bootstrap ready; project verification is incomplete`. Follow [Getting Started](./docs/getting-started.md) to configure the derived project.

## How the Harness fits together

```text
make verify
├── check Harness shell scripts
├── run Harness regression tests
├── validate repository Skills
└── run the project's own checks
```

The GitHub Actions workflow is preconfigured so CI and local development use the same `make verify` entrypoint.

## Included in `0.1.0`

- `AGENTS.md` for durable project rules that Codex should follow on nearly every change.
- A repeatable Harness with regression tests and macOS/Linux CI.
- `harness-feedback`, an implicit-eligible Skill for improving durable guardrails from evidence.
- `grill-with-docs`, an explicit-only Skill for clarifying important decisions before implementation.

Project-specific checks still need configuration. An installer, automatic updates, and the broader development Skill chain are planned rather than implemented.

## Documentation

- **First use:** [Getting Started](./docs/getting-started.md)
- **Connect tests, lint, and build:** [Harness](./docs/harness.md)
- **Adjust project rules and structure:** [Customization](./docs/customization.md)
- **Use or change Skills:** [Skills](./docs/skills.md)

## Support and license

macOS with Bash 3.2+ and Linux with Bash are supported. Native Windows and WSL are not officially supported in `0.1.0`.

MIT licensed. The adapted `grill-with-docs` Skill retains its upstream MIT notice.
