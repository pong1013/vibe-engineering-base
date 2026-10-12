# Support Project Contract Discovery

The Global Workflow will support any Git repository, not only projects derived from `vibe-engineering-base`. When an explicit Project Contract is unavailable, the Workflow Controller will perform Contract Discovery by inspecting repository-owned instructions, documentation, tooling, and existing conventions, then ask the user only for consequential information it cannot establish. Restricting the workflow to base-derived projects was rejected because a user-scoped capability should remain useful across the user's repositories, accepting additional discovery complexity in exchange for broader adoption.

Discovered facts do not authorize consequential actions by themselves. The Workflow Controller must surface uncertainty and pass the relevant Human Gates before implementation or delivery.

When Contract Discovery finds reusable project facts, the Workflow Controller will offer to persist them as the repository's Project Contract. It must receive explicit user approval before writing that contract; once accepted, the repository-owned contract becomes the source for later workflow runs instead of repeating discovery.
