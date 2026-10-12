# Establish Workspace Isolation Before Writing

Before a Feature Run makes its first repository write, the Workflow Controller will establish a Workspace Gate: reuse a clean branch or worktree already dedicated to the feature, or create a feature branch when the current default branch is clean. Delaying isolation until implementation was rejected because Grill and specification stages may already create durable repository artifacts, while writing directly to a shared default branch would mix the Feature Run with unrelated work.

If the worktree contains changes that are unrelated or whose ownership is uncertain, the controller stops and asks the user how to proceed. It must not stash, discard, overwrite, or silently absorb those changes. When the Codex task already owns an isolated worktree, the controller reuses it rather than creating another one.

After recording the ownership baseline, reusing an already-clean dedicated branch or worktree does not require another confirmation. Creating or switching a branch, resolving ambiguous existing changes, or otherwise changing workspace state remains gated and must be revalidated before the first write.
