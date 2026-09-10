---
name: project-workflow
description: Implement, diagnose, or review the primary product workflow in this repository. Use when a task changes product behavior, public interfaces, documentation, or regression tests; customize this description so it names the project's actual domain and triggers.
---

# Project Workflow

Replace this introduction with the smallest amount of project-specific context an agent cannot reliably discover from the codebase.

## Locate the change

- List the canonical directories for product code, tests, configuration, and user-facing documentation.
- Point to an architecture document when a change crosses layers.
- Keep routing guidance concise; do not duplicate information that search can discover quickly.

## Preserve invariants

- List compatibility requirements and behavior that must remain stable.
- Define safety boundaries for destructive or externally visible actions.
- State which public interfaces must stay synchronized.

## Verify the behavior

- Name the focused test commands for this workflow.
- Require assertions for important negative side effects.
- Finish with the repository-wide verification command.
