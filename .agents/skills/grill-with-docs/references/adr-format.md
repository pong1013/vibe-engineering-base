# Architecture decision record format

Use an ADR only when a decision is hard to reverse, surprising without context, and based on a real trade-off.

## Location and numbering

- Put system-wide decisions in `/docs/adr/`.
- In a multi-context repository, put a context-specific decision in the relevant `<context>/docs/adr/`.
- Create the directory only when the first qualifying ADR is accepted.
- Name files sequentially as `NNNN-short-slug.md`, using the next unused four-digit number in that directory.

## Minimum structure

```markdown
# Decision title

One short paragraph stating the context, the chosen option, and why it was selected over the meaningful alternatives.
```

Add consequences or rejected alternatives only when they preserve rationale that the minimum paragraph cannot express clearly. Do not turn an ADR into a full specification or implementation plan.
