---
name: grill-with-docs
description: Stress-test a fuzzy plan or design through a decision-by-decision interview and record settled domain language and durable architectural decisions. Use only when explicitly invoked with $grill-with-docs; do not use for ordinary implementation or minor changes.
---

# Grill with Docs

Clarify a plan or design before implementation. Keep the interview and documentation work separate from building the proposed change.

## Establish the current context

- Inspect the relevant code, documentation, repository state, and existing decisions before asking questions. Resolve discoverable facts yourself.
- Read `CONTEXT-MAP.md` when present, then read the relevant `CONTEXT.md` files and ADRs. Do not invent a context map.
- If the repository still identifies itself as `vibe-engineering-base`, warn that generated project knowledge will be inherited by repositories created from the base. Wait for confirmation before writing that knowledge.

## Walk the decision tree

- Identify the decisions that must be settled and their dependencies.
- Ask exactly one decision question at a time. Wait for the answer before moving to a dependent question.
- Include a recommended answer and the important trade-off behind it.
- Challenge ambiguous or conflicting terms. When the code and the user's explanation disagree, surface the conflict instead of silently choosing one.
- Do not implement the proposed product change during the grilling session.

## Record only durable knowledge

- When a project-specific term becomes canonical, read [references/context-format.md](references/context-format.md) and update the appropriate glossary immediately.
- For a single-context repository, lazily create or update the root `CONTEXT.md`.
- If an existing `CONTEXT-MAP.md` identifies multiple contexts, update the mapped context's `CONTEXT.md`. Do not create `CONTEXT-MAP.md` automatically.
- Offer an ADR only when the decision is hard to reverse, surprising without its rationale, and the result of a real trade-off. When all three conditions hold, read [references/adr-format.md](references/adr-format.md) and write the ADR under the relevant `docs/adr/` directory.
- Keep implementation details, specifications, temporary notes, and ordinary reversible choices out of the glossary and ADRs.
- Create no file when nothing qualifies. Treat generated files as normal project documentation that should be reviewed and committed.

## Finish the session

- Summarize settled terminology, ADRs created or changed, unresolved decisions, and the recommended next action.
- State clearly that answers not captured in the glossary or an ADR remain only in the conversation; do not present this workflow as a complete specification.

## Provenance

This Codex-native, self-contained workflow is adapted from Matt Pocock's `grill-with-docs`, `grilling`, and `domain-modeling` Skills. See [LICENSE](LICENSE) for the upstream MIT license.
