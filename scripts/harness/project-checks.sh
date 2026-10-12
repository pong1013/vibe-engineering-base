#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_CHECKS_CONFIGURED=1

if [[ "${PROJECT_CHECKS_CONFIGURED}" != "1" ]]; then
  echo "WARNING: project checks are not configured. Edit scripts/harness/project-checks.sh." >&2
  exit 0
fi

bash "${ROOT_DIR}/scripts/harness/validate-skills.sh"
bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh"
