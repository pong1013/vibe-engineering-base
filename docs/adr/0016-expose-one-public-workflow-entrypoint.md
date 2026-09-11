# Expose One Public Workflow Entrypoint

Version 1 of the Global Workflow plugin will expose `$ship-feature` as its only public Skill. Grill, specification, ticketing, implementation, testing, review, and delivery remain internal stages loaded and controlled by that Skill; users may request a stopping point or resume from an existing specification or ticket set without invoking those stages separately. Exposing every stage as a public Skill was rejected because it recreates the manual chaining and cognitive load the Workflow Controller is intended to remove.

The plugin, Skill sources, and installation configuration belong in the separate `ai-workflow` repository established by ADR 0001. The `vibe-engineering-base` README will explain the workflow with a Mermaid diagram and provide a one-prompt user-scope installation path, but the base will neither contain nor silently install the Global Workflow.
