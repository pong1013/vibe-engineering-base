# Remove Global Workflow Stages from the Base

`grill-with-docs` will move out of `vibe-engineering-base` and become a stage of the separately distributed Global Workflow, while `harness-feedback` will remain repository-scoped because it turns evidence from the current project's work into changes to that project's instructions, tests, Project Contract, or Harness. Keeping every reusable workflow stage in the base was rejected because derived repositories would own duplicate copies that drift, while removing every Skill was rejected because repository-learning behavior still belongs with the project it improves.

The inactive `examples/project-skill` scaffold will remain as guidance for creating genuinely project-specific Skills. This decision records the intended boundary only; removing or relocating files belongs to the later implementation change.
