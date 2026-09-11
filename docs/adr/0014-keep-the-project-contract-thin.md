# Keep the Project Contract Thin

The standard `.agents/project-contract.md` will organize workflow-facing information under Verification, Knowledge, Work artifacts, Workspace, and Delivery. It will contain canonical commands, locations, and policies or pointers to their authoritative sources, not duplicate architecture explanations, coding standards, specifications, domain language, or facts that are cheap to discover from executable tooling. A comprehensive project description was rejected because it would become a stale second source of truth.

Fields are optional when the repository has no corresponding policy. In particular, a branch prefix is recorded only when the project explicitly requires one; otherwise the Workflow Controller proposes a safe feature branch name at the Workspace Gate. Repository instructions and an explicit Project Contract policy outrank naming suggestions, while branch history alone is not sufficient evidence to create a permanent rule.

Verification is never implied by a successful bootstrap self-check. The contract records `Status: bootstrap` with an unconfigured complete command until real project checks exist, then changes to `Status: complete`; Workflow Controllers must gate rather than enter Delivery when the status, command output, and executable configuration do not agree.
