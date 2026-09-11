# Isolate Each Feature Run in One Codex Task

Each Feature Run will be owned by one Codex task, and a task may not control multiple unfinished Feature Runs at once. The Workflow Controller keeps transient stage progress in that task, while specifications, tickets, ADRs, and other durable outcomes remain repository-owned artifacts. A global or repository-level workflow-state database was rejected because it would add coordination and stale-state failure modes without improving the normal single-feature conversation.

Concurrent Feature Runs in the same repository should use separate branches or worktrees when their edits can overlap. The user-scoped Global Workflow contains no mutable project or run state, so installing it globally does not mix the conversation context of separate tasks.
