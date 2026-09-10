#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CODEX_BIN="${HARNESS_CODEX_BIN:-codex}"

if ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  echo "Codex CLI is required for the Harness audit." >&2
  exit 1
fi

cd "${ROOT_DIR}"

"${CODEX_BIN}" exec --ephemeral --sandbox read-only \
  -c 'model_reasoning_effort="medium"' \
  "Run a bounded repository Harness feedback audit. Read AGENTS.md and the harness-feedback Skill. Inspect git status, unstaged changes, staged changes, and relevant untracked files; inspect the latest commit only when the tree is clean. Limit inspection to Harness files and evidence-related changes. Do not run tests or edit files. Return at most three evidence-backed, reusable improvements for AGENTS.md, an existing Skill, or deterministic verification. Prefer no recommendation when a lesson is one-off or already captured."
