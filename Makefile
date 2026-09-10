SHELL := /bin/bash

.PHONY: verify test harness-audit

verify:
	@bash scripts/harness/verify.sh

test:
	@bash tests/run.sh

harness-audit:
	@bash scripts/harness/audit.sh
