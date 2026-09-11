# Separate Parallel Agent Write Ownership

During implementation, the Workflow Controller may run an Implementation Agent and an independent Test Agent in parallel, but it must assign non-overlapping writable files before they begin. The Implementation Agent owns production changes and the Test Agent owns separate test files derived directly from the approved specification and tickets. Allowing both agents to edit arbitrary files concurrently was rejected because shared-worktree races can overwrite work and because implementation-driven test changes weaken independent verification.

When tests must be colocated with production code or file ownership cannot be separated safely, the Test Agent will produce a test patch or test design without modifying the overlapping file. The Workflow Controller may apply that work only after the conflicting writer has returned control.
