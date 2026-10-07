# Route Review Findings by Ownership

The Review Agent will remain independent and report findings without editing the implementation or its tests. The Workflow Controller will classify each finding and route production defects to the Implementation Agent, test defects or coverage gaps to the Test Agent, and unresolved specification conflicts to an Exception Gate. Sending every finding to the Implementation Agent was rejected because it would let the implementation owner weaken independent tests and would blur responsibility for the evidence being reviewed.

After either worker makes a correction, the workflow reruns affected tests, executes the Project Contract's complete verification entrypoint, and returns the resulting diff and evidence to review before delivery.
