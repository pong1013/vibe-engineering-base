#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_RUN=0
TESTS_FAILED=0
TEST_TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vibe-engineering-test.XXXXXX")"

cleanup_temp_root() {
  if [[ -d "${TEST_TEMP_ROOT}" && "$(basename "${TEST_TEMP_ROOT}")" == vibe-engineering-test.* ]]; then
    rm -rf -- "${TEST_TEMP_ROOT}"
  fi
}

trap cleanup_temp_root EXIT

fail() {
  echo "FAIL: $*" >&2
  return 1
}

run_test() {
  local name="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))

  if ("$@"); then
    echo "PASS: ${name}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

new_temp_dir() {
  test_tmp="${TEST_TEMP_ROOT}/case-${TESTS_RUN}"
  mkdir -p "${test_tmp}"
}

write_valid_skill() {
  local skills_dir="$1"
  local name="${2:-sample-workflow}"
  local invocation_policy="${3:-}"
  mkdir -p "${skills_dir}/${name}/agents"
  printf '%s\n' \
    '---' \
    "name: ${name}" \
    'description: Apply a repeatable sample workflow. Use when a sample task requires this repository procedure.' \
    '---' \
    '' \
    '# Sample Workflow' \
    '' \
    'Inspect the request and follow the repository procedure.' \
    > "${skills_dir}/${name}/SKILL.md"
  printf '%s\n' \
    'interface:' \
    '  display_name: "Sample Workflow"' \
    '  short_description: "Apply the repository sample workflow"' \
    "  default_prompt: \"Use \$${name} to handle this repository task.\"" \
    > "${skills_dir}/${name}/agents/openai.yaml"
  if [[ -n "${invocation_policy}" ]]; then
    printf '%s\n' \
      'policy:' \
      "  allow_implicit_invocation: ${invocation_policy}" \
      >> "${skills_dir}/${name}/agents/openai.yaml"
  fi
}

test_default_project_checks_warn_and_pass() {
  local output
  if ! output="$(bash "${ROOT_DIR}/scripts/harness/project-checks.sh" 2>&1)"; then
    fail "default project checks should pass"
    return
  fi
  [[ "${output}" == *"WARNING: project checks are not configured"* ]] || fail "missing configuration warning"
}

test_verify_reports_bootstrap_state() {
  local output

  if ! output="$(HARNESS_SKIP_TESTS=1 bash "${ROOT_DIR}/scripts/harness/verify.sh" 2>&1)"; then
    fail "default verification should pass in bootstrap state"
    return
  fi
  [[ "${output}" == *"Harness checks: passed"* ]] || fail "missing Harness summary"
  [[ "${output}" == *"Repository Skills: passed"* ]] || fail "missing Skill summary"
  [[ "${output}" == *"Project checks: not configured"* ]] || fail "missing project checks state"
  [[ "${output}" == *"Overall: bootstrap ready; project verification is incomplete"* ]] || \
    fail "missing incomplete verification summary"
  [[ "${output}" != *"Overall: verification passed"* ]] || fail "bootstrap state claimed complete verification"
}

test_valid_skill_passes() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills"
  HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null
}

test_skill_name_mismatch_fails() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills"
  sed 's/name: sample-workflow/name: another-name/' \
    "${test_tmp}/skills/sample-workflow/SKILL.md" \
    > "${test_tmp}/invalid-skill"
  mv "${test_tmp}/invalid-skill" "${test_tmp}/skills/sample-workflow/SKILL.md"

  if HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null 2>&1; then
    fail "validator accepted a mismatched Skill name"
  fi
}

test_skill_placeholder_fails() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills"
  printf '\n[TODO: finish this workflow]\n' >> "${test_tmp}/skills/sample-workflow/SKILL.md"

  if HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null 2>&1; then
    fail "validator accepted an unfinished placeholder"
  fi
}

test_invalid_agent_metadata_fails() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills"
  printf '%s\n' 'interface:' '  display_name: "Sample Workflow"' \
    > "${test_tmp}/skills/sample-workflow/agents/openai.yaml"

  if HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null 2>&1; then
    fail "validator accepted incomplete agent metadata"
  fi
}

test_invocation_policy_values_pass() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills" "implicit-workflow" "true"
  write_valid_skill "${test_tmp}/skills" "explicit-workflow" "false"
  HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null
}

test_invalid_invocation_policy_fails() {
  new_temp_dir
  write_valid_skill "${test_tmp}/skills" "sample-workflow" "sometimes"

  if HARNESS_SKILLS_DIR="${test_tmp}/skills" bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null 2>&1; then
    fail "validator accepted a non-boolean invocation policy"
  fi
}

test_bundled_skills_are_complete() {
  local grill_dir="${ROOT_DIR}/.agents/skills/grill-with-docs"
  local feedback_metadata="${ROOT_DIR}/.agents/skills/harness-feedback/agents/openai.yaml"

  [[ -f "${grill_dir}/SKILL.md" ]] || fail "missing grill-with-docs SKILL.md"
  [[ -f "${grill_dir}/references/context-format.md" ]] || fail "missing context format reference"
  [[ -f "${grill_dir}/references/adr-format.md" ]] || fail "missing ADR format reference"
  [[ -f "${grill_dir}/LICENSE" ]] || fail "missing upstream license"
  grep -Eq '^  allow_implicit_invocation: false[[:space:]]*$' \
    "${grill_dir}/agents/openai.yaml" || fail "grill-with-docs must be explicit-only"
  grep -Eq '^  allow_implicit_invocation: true[[:space:]]*$' \
    "${feedback_metadata}" || fail "harness-feedback must allow implicit invocation"
}

test_project_check_success_propagates() {
  new_temp_dir
  local output
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${test_tmp}/project-checks.sh"
  if ! output="$(HARNESS_SKIP_TESTS=1 HARNESS_PROJECT_CHECKS="${test_tmp}/project-checks.sh" \
    bash "${ROOT_DIR}/scripts/harness/verify.sh" 2>&1)"; then
    fail "configured project checks should pass"
    return
  fi
  [[ "${output}" == *"Project checks: passed"* ]] || fail "missing successful project checks summary"
  [[ "${output}" == *"Overall: verification passed"* ]] || fail "missing complete verification summary"
}

test_project_check_failure_propagates() {
  new_temp_dir
  printf '%s\n' '#!/usr/bin/env bash' 'exit 23' > "${test_tmp}/project-checks.sh"

  HARNESS_SKIP_TESTS=1 HARNESS_PROJECT_CHECKS="${test_tmp}/project-checks.sh" \
    bash "${ROOT_DIR}/scripts/harness/verify.sh" >/dev/null 2>&1
  local status=$?
  [[ "${status}" -eq 23 ]] || fail "expected project check exit 23, got ${status}"
}

test_audit_requires_codex() {
  new_temp_dir
  local output
  output="$(HARNESS_CODEX_BIN="${test_tmp}/missing-codex" bash "${ROOT_DIR}/scripts/harness/audit.sh" 2>&1)"
  local status=$?
  [[ "${status}" -ne 0 ]] || fail "audit unexpectedly passed without Codex CLI"
  [[ "${output}" == *"Codex CLI is required"* ]] || fail "audit did not explain the missing dependency"
}

test_markdown_internal_links_resolve() {
  local markdown_file
  local link_match
  local target
  local resolved
  local failed=0

  while IFS= read -r markdown_file; do
    while IFS= read -r link_match; do
      target="${link_match#](}"
      target="${target%)}"
      target="${target%%#*}"

      case "${target}" in
        ""|http://*|https://*|mailto:*|/*)
          continue
          ;;
      esac

      resolved="$(dirname "${markdown_file}")/${target}"
      if [[ ! -e "${resolved}" ]]; then
        echo "Broken Markdown link: ${markdown_file} -> ${target}" >&2
        failed=1
      fi
    done < <(grep -Eo '\]\([^)]+\)' "${markdown_file}" || true)
  done < <(find "${ROOT_DIR}" -type f -name '*.md' -not -path '*/.git/*' | sort)

  [[ "${failed}" -eq 0 ]] || fail "one or more Markdown links do not resolve"
}

test_bilingual_document_pairs_exist() {
  local english_file
  local translated_file
  local failed=0

  [[ -f "${ROOT_DIR}/README.zh-TW.md" ]] || {
    echo "Missing Traditional Chinese pair for README.md" >&2
    failed=1
  }

  while IFS= read -r english_file; do
    translated_file="${english_file%.md}.zh-TW.md"
    if [[ ! -f "${translated_file}" ]]; then
      echo "Missing Traditional Chinese pair: ${translated_file}" >&2
      failed=1
    fi
  done < <(find "${ROOT_DIR}/docs" -maxdepth 1 -type f -name '*.md' ! -name '*.zh-TW.md' | sort)

  [[ "${failed}" -eq 0 ]] || fail "one or more bilingual document pairs are missing"
}

test_readmes_match_version() {
  local version

  version="$(tr -d '[:space:]' < "${ROOT_DIR}/VERSION")"
  [[ -n "${version}" ]] || {
    fail "VERSION is empty"
    return
  }
  grep -Fq "\`${version}\`" "${ROOT_DIR}/README.md" || fail "README.md does not mention VERSION ${version}"
  grep -Fq "\`${version}\`" "${ROOT_DIR}/README.zh-TW.md" || \
    fail "README.zh-TW.md does not mention VERSION ${version}"
}

run_test "default project checks warn and pass" test_default_project_checks_warn_and_pass
run_test "verify reports bootstrap state" test_verify_reports_bootstrap_state
run_test "valid Skill passes" test_valid_skill_passes
run_test "Skill name mismatch fails" test_skill_name_mismatch_fails
run_test "unfinished Skill placeholder fails" test_skill_placeholder_fails
run_test "invalid agent metadata fails" test_invalid_agent_metadata_fails
run_test "valid invocation policy values pass" test_invocation_policy_values_pass
run_test "invalid invocation policy fails" test_invalid_invocation_policy_fails
run_test "bundled Skills are complete" test_bundled_skills_are_complete
run_test "successful project checks propagate" test_project_check_success_propagates
run_test "failed project checks propagate" test_project_check_failure_propagates
run_test "audit requires Codex CLI" test_audit_requires_codex
run_test "Markdown internal links resolve" test_markdown_internal_links_resolve
run_test "bilingual document pairs exist" test_bilingual_document_pairs_exist
run_test "README versions match VERSION" test_readmes_match_version

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ "${TESTS_FAILED}" -eq 0 ]]
