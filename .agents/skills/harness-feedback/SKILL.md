---
name: harness-feedback
description: Turn concrete evidence from completed changes, bug fixes, reviews, or repeated agent mistakes into focused improvements to a repository's AGENTS.md, Project Contract, Skills, tests, or verification. Use for Harness retrospectives and maintenance, not as a mandatory step for every ordinary edit.
---

# Harness Feedback

Inspect the concrete evidence first: failed tests, review comments, user corrections, recent commits, and relevant working-tree changes. Do not add a rule based only on speculation.

## Route the lesson

- Add or strengthen a deterministic test when a machine can recognize the failure.
- Update `AGENTS.md` only for short, repository-wide guidance that should affect nearly every future task.
- Update `.agents/project-contract.md` for workflow-facing commands, locations, or policies that were resolved from repository evidence.
- Update an existing Skill for recurring task-specific judgment or workflow knowledge.
- Create a Skill only when the capability has a distinct trigger and enough reusable guidance to justify one.
- Put architecture explanations in project documentation rather than always-loaded instructions.

Prefer the smallest durable improvement. State each rule once, replace obsolete guidance, and phrase rules as observable behavior or decision boundaries.

## Close the loop

- Keep `AGENTS.md` short and confirm that Skill descriptions have precise triggers.
- Keep the Project Contract a thin index and do not duplicate its authoritative sources.
- Run `make verify` after repository changes.
- Validate every new or substantially revised Skill and remove scaffold placeholders.
- Summarize the evidence that justified the Harness change. Recommend no update when existing controls already cover the lesson.
