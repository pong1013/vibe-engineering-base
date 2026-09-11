# Include Ticket Creation in Specification Approval

The Specification Human Gate will state that approval authorizes the Workflow Controller to create tickets within the approved scope in the tracker selected by the Project Contract, then continue automatically into implementation and testing. A separate routine ticket-creation approval was rejected because it would interrupt the automatic post-specification flow, while creating external tickets without disclosing that consequence at the gate was rejected because specification approval alone would otherwise be ambiguous.

The authorization covers only tickets derived from the approved specification in the named tracker. Missing tracker configuration, unavailable permissions, or ticket content that requires a new consequential decision raises an Exception Gate. Delivery remains separately gated.
