# Recommend the Intake Route

At the start of a Feature Run, the Workflow Controller will inspect the request and repository, recommend whether to enter Grill or proceed directly, explain the unresolved decisions behind that recommendation, and wait for the user to confirm the route. Automatically grilling every request was rejected because small, precise changes do not earn the added interaction, while silently skipping Grill was rejected because unresolved product, domain, architecture, or safety decisions require human participation.

An approved specification or a small, clear, low-risk request normally bypasses Grill. The user may also state `start with grill` or `skip grill` in the initial invocation; that directive satisfies the Intake Gate without a duplicate confirmation, subject to an Exception Gate if repository evidence makes the chosen route unsafe or underspecified.
