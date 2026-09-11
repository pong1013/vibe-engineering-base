# Separate the Project Contract from the Global Workflow

`vibe-engineering-base` will provide the repository-owned Project Contract, Harness, and CI, while a separate `ai-workflow` repository will distribute the user-scoped Workflow Controller and its reusable development stages as a plugin. This separation keeps project-specific rules and verification versioned with each derived project while allowing the project-independent workflow to be installed and upgraded once per user; bundling the complete workflow into the base was rejected because every derived repository would receive duplicate copies that drift independently.

The base may recommend and link to the Global Workflow, but it does not own or silently install it. The Global Workflow must read the current repository's Project Contract before acting, and consequential transitions remain subject to its documented Human Gates.
