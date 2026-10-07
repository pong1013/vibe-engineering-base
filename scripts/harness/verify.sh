#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
shell_files=()

while IFS= read -r -d '' file; do
  shell_files+=("${file}")
done < <(
  find "${ROOT_DIR}/scripts/harness" "${ROOT_DIR}/tests" \
    -type f -name '*.sh' -print0
)

echo "Checking Harness Bash syntax (${#shell_files[@]} files)..."
for file in "${shell_files[@]}"; do
  bash -n "${file}"
done

if [[ "${HARNESS_SKIP_TESTS:-0}" != "1" ]]; then
  echo "Running Harness regression tests..."
  bash "${ROOT_DIR}/tests/run.sh"
fi

echo "Validating active repository Skills..."
bash "${ROOT_DIR}/scripts/harness/validate-skills.sh"

echo "Validating Project Contract..."
bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh"
contract_file="${HARNESS_PROJECT_CONTRACT:-${ROOT_DIR}/.agents/project-contract.md}"
contract_status="$(awk '
  $0 == "## Verification" { inside = 1; next }
  /^## / { inside = 0 }
  inside && /^- Status: / {
    sub(/^- Status: /, "")
    print
    exit
  }
' "${contract_file}")"

default_project_checks="${ROOT_DIR}/scripts/harness/project-checks.sh"
project_checks="${HARNESS_PROJECT_CHECKS:-${default_project_checks}}"
if [[ ! -f "${project_checks}" ]]; then
  echo "Project checks file not found: ${project_checks}" >&2
  exit 1
fi

project_checks_state="configured"
if [[ "${project_checks}" == "${default_project_checks}" ]]; then
  project_checks_configured="$(
    awk -F= '
      /^PROJECT_CHECKS_CONFIGURED=/ {
        gsub(/[[:space:]]/, "", $2)
        print $2
        exit
      }
    ' "${project_checks}"
  )"
  case "${project_checks_configured}" in
    0) project_checks_state="not-configured" ;;
    1) project_checks_state="configured" ;;
    *)
      echo "PROJECT_CHECKS_CONFIGURED must be set to 0 or 1 in ${project_checks}." >&2
      exit 1
      ;;
  esac
fi

echo "Running project checks..."
bash "${project_checks}"

echo
echo "Verification summary:"
echo "  Harness checks: passed"
echo "  Repository Skills: passed"
echo "  Project Contract: passed"
echo "  Contract verification status: ${contract_status}"
if [[ "${project_checks_state}" == "not-configured" ]]; then
  echo "  Project checks: not configured"
  echo "  Overall: bootstrap ready; project verification is incomplete"
  echo "HARNESS_VERIFICATION_STATUS=bootstrap"
elif [[ "${contract_status}" == "bootstrap" ]]; then
  echo "  Project checks: passed"
  echo "  Overall: project checks passed; contract remains bootstrap"
  echo "HARNESS_VERIFICATION_STATUS=bootstrap"
else
  echo "  Project checks: passed"
  echo "  Overall: verification passed"
  echo "HARNESS_VERIFICATION_STATUS=complete"
fi
