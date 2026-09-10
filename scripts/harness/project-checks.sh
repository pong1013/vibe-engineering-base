#!/usr/bin/env bash

set -euo pipefail

# Set this to 1 after replacing the warning branch with this project's
# canonical test, lint, build, or other verification commands.
PROJECT_CHECKS_CONFIGURED=0

if [[ "${PROJECT_CHECKS_CONFIGURED}" != "1" ]]; then
  echo "WARNING: project checks are not configured. Edit scripts/harness/project-checks.sh." >&2
  exit 0
fi

# Add project-specific verification commands below this line.
