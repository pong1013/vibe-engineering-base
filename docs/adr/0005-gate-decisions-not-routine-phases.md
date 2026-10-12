# Gate Decisions, Not Routine Phases

After the user approves a specification, the Workflow Controller will create tickets and proceed into implementation without another routine approval when the tickets only decompose the approved work. It will raise an Exception Gate when ticketing or a later stage exposes a consequential decision, risk, or scope change that the specification did not settle. Requiring approval after every phase was rejected because it turns deterministic workflow transitions into repetitive chat prompts, while removing gates entirely would allow new decisions to pass without human review.

An earlier approval authorizes only work within its stated scope. It does not authorize unrelated changes or delivery actions that have their own Human Gate.
