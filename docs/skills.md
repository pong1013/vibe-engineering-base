# Skills

[English](./skills.md) | [繁體中文](./skills.zh-TW.md) | [Back to README](../README.md)

This project uses two kinds of Codex Skill:

- a user-scoped `$vibe-engineering` Skill, installed once and used to configure or maintain a selected project folder;
- repository Skills under `.agents/skills/`, which travel with a project and encode its repeatable workflows.

Skills complement the always-loaded `AGENTS.md`; they do not replace durable repository guidance.

## User-scoped `$vibe-engineering`

Install the source at `skills/vibe-engineering` with the preinstalled `$skill-installer`:

```text
$skill-installer Install the Skill from https://github.com/pong1013/vibe-engineering-base/tree/main/skills/vibe-engineering
```

The installed Skill is available on the next turn. It accepts a current or explicit absolute project directory and supports four intents:

| Intent | Behavior |
| --- | --- |
| setup | Previews and then installs selected Harness capabilities in a Git repository or plain folder. |
| status | Reports managed paths as current, modified, or missing without writing. |
| upgrade | Previews version changes; modified managed files remain conflicts until the user reviews a replacement decision. |
| learn | Routes concrete evidence to guidance, check proposals, or a project Skill when its reuse threshold is met. |

Setup and upgrade bind approval to the target and current file state with a plan token. Writes are atomic. The manifest at `.agents/vibe-engineering/manifest.json` records the source version, selected capabilities, managed paths, and checksums without storing secrets.

The Skill owns only its bounded block in `AGENTS.md`. Existing project content and project-created Skills remain project-owned. A plain folder receives no Git, CI, branch, commit, or pull request assumptions.

## Repository Skill discovery

Codex scans `.agents/skills/` from the current working directory up to the repository root. Skill information is loaded progressively:

1. The Skill name, description, and path are available for selection.
2. The full `SKILL.md` body is loaded only when Codex selects or is explicitly given that Skill.
3. Referenced files and scripts are read or run only when the workflow needs them.

An implicitly enabled Skill is eligible for selection when its description matches a request; it does not run on every task. Explicit invocation uses `$skill-name`. Invocation policy is defined in `agents/openai.yaml`. See the official [Codex Skills documentation](https://learn.chatgpt.com/docs/build-skills).

## Bundled repository Skill

| Skill | Invocation | Responsibility |
| --- | --- | --- |
| `harness-feedback` | Implicit-eligible or `$harness-feedback` | Uses evidence from completed work, reviews, and repeated mistakes to propose focused improvements to durable repository guardrails. |

Use `harness-feedback` after concrete evidence exposes a reusable lesson. It routes machine-recognizable failures into tests or verification, repository-wide guidance into `AGENTS.md`, and repeatable task-specific judgment into a Skill. It should recommend no change when the lesson is one-off or already covered.

Depending on the approved request, it may update `AGENTS.md`, an existing Skill, tests, or Harness verification. It is not a mandatory closing step for ordinary edits.

The folder under `examples/project-skill/` is inactive because it is outside `.agents/skills/`. Copy and customize it only when the project has a repeatable workflow with a distinct trigger.

## Add or remove a repository Skill

- Put an active repository Skill at `.agents/skills/<skill-name>/SKILL.md`.
- Include matching `agents/openai.yaml` metadata and choose an invocation policy deliberately.
- Keep the description narrow enough to avoid unrelated implicit selection.
- Run `make verify` so the Harness checks active Skill names, required metadata, invocation policy, and unfinished placeholders.
- Remove a Skill directory when its workflow should no longer travel with the project.

For a starting structure, copy `examples/project-skill/` into `.agents/skills/<skill-name>/`, then replace every generic name and instruction with the project's actual workflow.
