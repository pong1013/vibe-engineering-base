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

The first run should succeed with this explicit bootstrap summary:

```text
Harness checks: passed
Repository Skills: passed
Project checks: not configured
Overall: bootstrap ready; project verification is incomplete
```

This means the template itself works. It does **not** mean your product tests, lint, or build have run. Connect those commands by following [Getting Started](./docs/getting-started.md).

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
