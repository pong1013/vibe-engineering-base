# Context glossary format

Use a context glossary to define the project's canonical domain language, not its implementation.

## Location

- For a single-context repository, use `/CONTEXT.md`.
- When `/CONTEXT-MAP.md` already exists, follow its paths and update the relevant `<context>/CONTEXT.md`.
- Never create `CONTEXT-MAP.md` as a side effect of this workflow.

Create the selected `CONTEXT.md` only when the first project-specific term is settled.

## Structure

```markdown
# Context name

One or two sentences explaining the domain boundary.

## Language

**Canonical term**:

A precise definition in one or two sentences.

_Avoid_: ambiguous synonym, obsolete term
```

Group terms under additional headings only when distinct clusters emerge.

## Rules

- Choose one canonical word when several words refer to the same concept.
- Define what the concept is, not how the current code implements it.
- Include only language specific to the project's domain. Exclude general programming terminology, specifications, task notes, and architecture decisions.
- Preserve valid existing definitions. Surface a conflict and resolve it with the user before changing established language.
