# Expose One Public Workflow Entrypoint

Status: Superseded by [ADR 0018](./0018-offer-template-and-skill-entrypoints.md).

Version 1 of the Global Workflow plugin will expose `$ship-feature` as its only public Skill. Grill, specification, ticketing, implementation, testing, review, and delivery remain internal stages loaded and controlled by that Skill; users may request a stopping point or resume from an existing specification or ticket set without invoking those stages separately. Exposing every stage as a public Skill was rejected because it recreates the manual chaining and cognitive load the Workflow Controller is intended to remove.

The plugin, Skill sources, and installation configuration belong in the separate `ai-workflow` repository established by ADR 0001. The `vibe-engineering-base` README will explain the workflow with a Mermaid diagram and provide a one-prompt user-scope installation path, but the base will neither contain nor silently install the Global Workflow.

ADR 0018 replaced the README exposure and installation decision with two base-owned entrypoints: the GitHub Template and the user-scoped `$vibe-engineering` project configurator. The earlier `$ship-feature` proposal remains here as historical context for the separate Global Workflow, but it is no longer an active requirement for this repository and does not authorize changes to that repository or to user-scoped Global Workflow configuration.
