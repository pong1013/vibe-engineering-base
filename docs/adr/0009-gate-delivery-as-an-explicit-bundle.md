# Gate Delivery as an Explicit Bundle

After complete verification and review pass, the Workflow Controller will present one exact delivery bundle covering the files to stage, commit message, branch, remote, target branch, and whether it will push and create a pull or merge request. One explicit user approval authorizes only that displayed bundle, after which the controller may execute its steps without requesting routine confirmation between them. Separate approval for every Git command was rejected as unnecessary friction, while treating the original feature request as delivery authorization was rejected because it would hide consequential external actions.

The Project Contract may select `none`, `commit-only`, `push`, `pull-request`, or `merge-request` as its delivery mode. A changed target, unknown remote, protected branch, force operation, permission failure, or other expansion stops delivery and requires a new decision; the controller must never infer broader authority from the approved bundle.

Every mode enters the Delivery Gate. For `none`, the displayed bundle is explicitly a no-Git reviewed handoff; approval authorizes only that handoff and performs no repository or remote mutation.
