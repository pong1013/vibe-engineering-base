# Vibe Engineering Base

This context covers the boundary between a project's durable AI engineering environment and reusable development workflows installed for a user.

## Language

**Project Contract**:

The repository-owned rules, knowledge locations, verification entrypoints, and delivery policies that tell an agent how to work safely and correctly in one project. Its standard entrypoint is `.agents/project-contract.md`.

_Avoid_: project workflow, global configuration

**Global Workflow**:

A reusable development process installed at user scope and available across repositories. It supplies project-independent methods while obtaining project-specific behavior from the current repository's Project Contract.

_Avoid_: repository Skill, base workflow

**Workflow Controller**:

The single capability that owns a multi-stage development flow from intake through delivery, advances between stages, and remains responsible until the flow reaches a terminal state.

_Avoid_: Skill chain, automatic Skill switching

**Human Gate**:

A workflow boundary that requires an explicit human decision before the Workflow Controller may continue to a consequential next stage.

_Avoid_: manual step, workflow pause

**Exception Gate**:

A conditional Human Gate raised only when a later workflow stage discovers a consequential decision, risk, or scope change not covered by an earlier approval.

_Avoid_: phase approval, routine confirmation

**Contract Discovery**:

The process by which the Workflow Controller establishes a Project Contract from repository-owned instructions, documentation, tooling, and focused questions when no explicit contract is present.

_Avoid_: guessing, automatic setup

**Feature Run**:

One execution of the Global Workflow for one feature, owned by a single Codex task from intake until completion or cancellation.

_Avoid_: global workflow state, shared run
