# Target Codex for Version 1

Version 1 of `ai-workflow` will officially support Codex only. Its Workflow Controller may rely on Codex tasks, subagents, workspace and worktree behavior, approval boundaries, `$skill-installer`, and `agents/openai.yaml` instead of implementing compatibility layers for other agents. Cross-agent support was rejected for the first release because invocation, concurrency, permissions, installation, and Git capabilities differ enough to multiply the design and verification surface before the core workflow is proven.

Instructions may remain portable where that costs nothing, but behavior on Claude Code, Cursor, Gemini, or other hosts is not a Version 1 completion criterion.
