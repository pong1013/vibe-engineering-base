# Stop Review Loops When Progress Is Lost

The Workflow Controller will continue the implement, verify, and review loop while findings are changing, shrinking, or producing new evidence. It will raise an Exception Gate when the same blocking issue repeats without new evidence, the implementation and tests remain in unresolved conflict, the proposed correction exceeds the approved specification, or complete verification cannot run. An unconditional loop-until-pass was rejected because agents can repeat ineffective corrections indefinitely, while a fixed retry count was rejected because difficult work may still be making measurable progress.

At the Exception Gate, the controller preserves current work and reports the blocking decision, attempts, evidence, options, and recommendation. It does not discard changes or enter delivery. After the user decides, the same Feature Run resumes from the affected stage without requiring another `$ship-feature` invocation.
