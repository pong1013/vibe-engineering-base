#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_files=("${ROOT_DIR}"/tests/*_test.sh)

if [[ ! -e "${test_files[0]}" ]]; then
  echo "No test files found under ${ROOT_DIR}/tests" >&2
  exit 1
fi

for test_file in "${test_files[@]}"; do
  echo "==> $(basename "${test_file}")"
  bash "${test_file}"
done
