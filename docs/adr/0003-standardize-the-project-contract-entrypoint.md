# Standardize the Project Contract Entrypoint

Repositories that persist workflow configuration will use `.agents/project-contract.md` as the standard Project Contract entrypoint. A stable, human-readable location lets the Global Workflow detect complete project guidance without reconstructing it on every run, while the contract can point to canonical instructions, tooling, and knowledge instead of copying their contents. Distributing the contract across unrelated existing files was rejected because there would be no reliable way to distinguish a complete contract from partial discovery.

When this file is absent, the Workflow Controller performs Contract Discovery and may offer to create it after explicit user approval.

The Project Contract is an entrypoint and index, not an override for repository truth. Repository instructions such as `AGENTS.md` take precedence, and executable tooling establishes observable facts. When these sources conflict with the contract, the Workflow Controller must stop the affected stage, surface the conflict, and wait for the user to approve a correction instead of guessing or silently updating the contract.
