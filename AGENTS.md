# Repository working agreement

## Working approach

- Inspect the existing implementation, nearby documentation, and repository state before changing code.
- Make the smallest coherent change that satisfies the request, and preserve unrelated user work.
- Keep architecture explanations in project documentation instead of expanding this file with one-off details.

## Safety and compatibility

- Preserve documented public behavior unless the task explicitly changes it.
- Validate exact targets before destructive actions, refuse uncertain state, and prefer reversible operations.
- Keep supported platforms and compatibility constraints intact unless the task explicitly narrows them.

## Change workflow

- Add or update deterministic tests for behavior changes and bug fixes.
- Keep user-facing documentation aligned with changed commands, options, defaults, or workflows.
- Run `make verify` before handing off. Report any relevant integration behavior that could not be exercised locally.

## Project-specific guidance

- Replace this section with concise architecture boundaries, canonical commands, and invariants that apply to nearly every task in the project.
- Put task-specific repeatable workflows in `.agents/skills/`, not in this always-loaded file.
