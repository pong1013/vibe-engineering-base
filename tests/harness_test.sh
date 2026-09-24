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

write_valid_project_contract() {
  local contract_file="$1"
  mkdir -p "$(dirname "${contract_file}")"
  printf '%s\n' \
    '# Project Contract' \
    '' \
    '## Verification' \
    '' \
    '- Status: complete' \
    '- Complete verification: `make verify`' \
    '- Project checks: `scripts/harness/project-checks.sh`' \
    '' \
    '## Knowledge' \
    '' \
    '- Repository instructions: `AGENTS.md`' \
    '- Domain language: unconfigured' \
    '- Architecture decisions: unconfigured' \
    '' \
    '## Work artifacts' \
    '' \
    '- Specifications: `docs/specs/`' \
    '- Ticket backend: unconfigured' \
    '' \
    '## Workspace' \
    '' \
    '- Default branch: discover from the repository' \
    '- Preserve unrelated working-tree changes: yes' \
    '' \
    '## Delivery' \
    '' \
    '- Mode: unconfigured' \
    '- Remote and target branch: discover and confirm before delivery' \
    '- Require Delivery Gate: yes' \
    > "${contract_file}"
}

write_valid_folder_project_contract() {
  local contract_file="$1"
  mkdir -p "$(dirname "${contract_file}")"
  printf '%s\n' \
    '# Project Contract' \
    '' \
    '## Verification' \
    '' \
    '- Status: bootstrap' \
    '- Bootstrap verification: unconfigured' \
    '- Complete verification: unconfigured' \
    '- Project checks: unconfigured' \
    '' \
    '## Knowledge' \
    '' \
    '- Project instructions: `AGENTS.md`' \
    '- Domain language: unconfigured' \
    '- Architecture decisions: unconfigured' \
    '' \
    '## Work artifacts' \
    '' \
    '- Specifications: unconfigured' \
    '- Task tracking: unconfigured' \
    '' \
    '## Workspace' \
    '' \
    '- Preserve unrelated workspace changes: yes' \
    '' \
    '## Delivery' \
    '' \
    '- Mode: unconfigured' \
    '- Destination: unconfigured' \
    '- Require Delivery Gate: yes' \
    > "${contract_file}"
}

test_source_project_checks_pass() {
  local output
  if ! output="$(bash "${ROOT_DIR}/scripts/harness/project-checks.sh" 2>&1)"; then
    fail "source project checks should pass"
    return
  fi
  [[ "${output}" == *"Validated 1 active repository skill(s)."* ]] || \
    fail "source checks did not validate repository Skills"
  [[ "${output}" == *"Validated Project Contract (complete)"* ]] || \
    fail "source checks did not validate the complete Project Contract"
}

test_verify_reports_complete_source_state() {
  local output

  if ! output="$(HARNESS_SKIP_TESTS=1 bash "${ROOT_DIR}/scripts/harness/verify.sh" 2>&1)"; then
    fail "source verification should pass in complete state"
    return
  fi
  [[ "${output}" == *"Harness checks: passed"* ]] || fail "missing Harness summary"
  [[ "${output}" == *"Repository Skills: passed"* ]] || fail "missing Skill summary"
  [[ "${output}" == *"Project Contract: passed"* ]] || fail "missing Project Contract summary"
  [[ "${output}" == *"Project checks: passed"* ]] || fail "missing project checks state"
  [[ "${output}" == *"Overall: verification passed"* ]] || fail "missing complete verification summary"
  [[ "${output}" == *"HARNESS_VERIFICATION_STATUS=complete"* ]] || \
    fail "missing machine-readable complete status"
}

test_valid_project_contract_passes() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null
}

test_folder_project_contract_profile_passes() {
  new_temp_dir
  write_valid_folder_project_contract "${test_tmp}/project-contract.md"
  HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    HARNESS_CONTRACT_PROFILE=folder \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null
}

test_contract_profiles_remain_strict() {
  new_temp_dir
  write_valid_folder_project_contract "${test_tmp}/project-contract.md"
  if HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "repository profile accepted a folder Contract"
    return
  fi
  if HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    HARNESS_CONTRACT_PROFILE=unknown \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "validator accepted an unknown Contract profile"
  fi
}

test_folder_contract_rejects_version_control_delivery_modes() {
  local mode
  for mode in none unconfigured; do
    new_temp_dir
    write_valid_folder_project_contract "${test_tmp}/project-contract.md"
    sed -i.bak "s/Mode: unconfigured/Mode: ${mode}/" "${test_tmp}/project-contract.md"
    HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
      HARNESS_CONTRACT_ROOT="${test_tmp}" \
      HARNESS_CONTRACT_PROFILE=folder \
      bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null || \
      fail "folder profile rejected delivery mode: ${mode}"
  done
  for mode in commit-only push pull-request merge-request; do
    new_temp_dir
    write_valid_folder_project_contract "${test_tmp}/project-contract.md"
    sed -i.bak "s/Mode: unconfigured/Mode: ${mode}/" "${test_tmp}/project-contract.md"
    if HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
      HARNESS_CONTRACT_ROOT="${test_tmp}" \
      HARNESS_CONTRACT_PROFILE=folder \
      bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
      fail "folder profile accepted delivery mode: ${mode}"
      return
    fi
  done
  for mode in none commit-only push pull-request merge-request unconfigured; do
    new_temp_dir
    write_valid_project_contract "${test_tmp}/project-contract.md"
    sed -i.bak "s/Mode: unconfigured/Mode: ${mode}/" "${test_tmp}/project-contract.md"
    HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
      HARNESS_CONTRACT_ROOT="${test_tmp}" \
      HARNESS_CONTRACT_PROFILE=repository \
      bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null || \
      fail "repository profile rejected delivery mode: ${mode}"
  done
}

test_missing_project_contract_fails() {
  new_temp_dir
  if HARNESS_PROJECT_CONTRACT="${test_tmp}/missing.md" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "validator accepted a missing Project Contract"
  fi
}

test_incomplete_project_contract_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed '/## Delivery/,$d' "${test_tmp}/project-contract.md" > "${test_tmp}/incomplete.md"

  if HARNESS_PROJECT_CONTRACT="${test_tmp}/incomplete.md" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "validator accepted an incomplete Project Contract"
  fi
}

test_duplicate_project_contract_section_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  printf '\n%s\n' '## Delivery' >> "${test_tmp}/project-contract.md"

  if HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "validator accepted a duplicate Project Contract section"
  fi
}

test_project_contract_placeholder_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  printf '\n%s\n' '[TODO: choose a tracker]' >> "${test_tmp}/project-contract.md"

  if HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null 2>&1; then
    fail "validator accepted an unfinished Project Contract placeholder"
  fi
}

assert_invalid_project_contract() {
  local expected_message="$1"
  local output
  if output="$(HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" 2>&1)"; then
    fail "validator accepted invalid Project Contract"
    return
  fi
  [[ "${output}" == *"${expected_message}"* ]] || \
    fail "validator did not report expected conflict: ${expected_message}"
}

test_invalid_delivery_mode_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak 's/Mode: unconfigured/Mode: destroy-everything/' "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "Mode must be"
}

test_unsafe_workspace_policy_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak 's/working-tree changes: yes/working-tree changes: no/' "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "must be 'yes'"
}

test_nonsensical_verification_command_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak 's/`make verify`/`false`/' "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "not an executable verification entrypoint"
}

test_unsafe_contract_path_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak 's#`AGENTS.md`#`../AGENTS.md`#' "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "must remain inside the repository"
}

test_tracker_configuration_reference_passes() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  mkdir -p "${test_tmp}/docs/agents"
  : > "${test_tmp}/docs/agents/issue-tracker.md"
  sed -i.bak \
    -e 's#Specifications: `docs/specs/`#Specifications: configured by `docs/agents/issue-tracker.md`#' \
    -e 's#Ticket backend: unconfigured#Ticket backend: configured by `docs/agents/issue-tracker.md`#' \
    "${test_tmp}/project-contract.md"
  HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null
}

test_missing_tracker_configuration_reference_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak \
    's#Specifications: `docs/specs/`#Specifications: configured by `docs/agents/issue-tracker.md`#' \
    "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "Specifications configuration reference file not found"
}

test_missing_ticket_backend_configuration_reference_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak \
    's#Ticket backend: unconfigured#Ticket backend: configured by `docs/agents/issue-tracker.md`#' \
    "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "Ticket backend configuration reference file not found"
}

test_unsafe_tracker_configuration_reference_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak \
    's#Specifications: `docs/specs/`#Specifications: configured by `../issue-tracker.md`#' \
    "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "Specifications configuration reference must remain inside the repository"
}

test_malformed_tracker_configuration_reference_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak \
    's#Ticket backend: unconfigured#Ticket backend: configured by docs/agents/issue-tracker.md#' \
    "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "Ticket backend must be"
}

test_verification_configuration_conflict_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  mkdir -p "${test_tmp}/scripts/harness"
  printf '%s\n' 'PROJECT_CHECKS_CONFIGURED=0' > "${test_tmp}/scripts/harness/project-checks.sh"
  assert_invalid_project_contract "Status is complete but make verify declares project checks unconfigured"
}

test_bootstrap_contract_passes() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak \
    -e 's/Status: complete/Status: bootstrap/' \
    -e '/Status: bootstrap/a\
- Bootstrap verification: `make verify`' \
    -e 's/Complete verification: `make verify`/Complete verification: unconfigured/' \
    "${test_tmp}/project-contract.md"
  HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    bash "${ROOT_DIR}/scripts/harness/validate-project-contract.sh" >/dev/null
}

test_misplaced_contract_field_fails() {
  new_temp_dir
  write_valid_project_contract "${test_tmp}/project-contract.md"
  sed -i.bak '/^- Mode: /d' "${test_tmp}/project-contract.md"
  sed -i.bak '/^- Status: complete/a\
- Mode: unconfigured' "${test_tmp}/project-contract.md"
  assert_invalid_project_contract "section 'Verification' contains unsupported field(s): Mode"
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
  local feedback_metadata="${ROOT_DIR}/.agents/skills/harness-feedback/agents/openai.yaml"

  [[ ! -e "${ROOT_DIR}/.agents/skills/grill-with-docs" ]] || \
    fail "grill-with-docs must not remain repository-scoped"
  grep -Eq '^  allow_implicit_invocation: true[[:space:]]*$' \
    "${feedback_metadata}" || fail "harness-feedback must allow implicit invocation"
}

test_onboarding_leads_with_two_entrypoints() {
  python3 - "${ROOT_DIR}/README.md" "${ROOT_DIR}/README.zh-TW.md" <<'PY'
from pathlib import Path
import sys

for filename in sys.argv[1:]:
    text = Path(filename).read_text()
    existing = text.index("skills/vibe-engineering")
    template = text.index("Use this template")
    harness = text.index("## How the Harness") if filename.endswith("README.md") else text.index("## Harness 如何運作")
    if not (existing < harness and template < harness):
        raise SystemExit(f"entrypoints must appear before Harness internals: {filename}")
PY
}

test_template_prompt_covers_configuration_before_verification() {
  python3 - "${ROOT_DIR}/README.md" "${ROOT_DIR}/README.zh-TW.md" <<'PY'
from pathlib import Path
import sys

required = {
    "README.md": [
        "project identity", "AGENTS.md", "tracker", "domain", "Status: bootstrap",
        "PROJECT_CHECKS_CONFIGURED=1", "make verify", "remaining bootstrap gaps",
    ],
    "README.zh-TW.md": [
        "專案身分", "AGENTS.md", "tracker", "domain", "Status: bootstrap",
        "PROJECT_CHECKS_CONFIGURED=1", "make verify", "仍未完成的 bootstrap 項目",
    ],
}
for filename in sys.argv[1:]:
    text = Path(filename).read_text()
    start = text.index("<!-- template-setup-prompt:start -->")
    end = text.index("<!-- template-setup-prompt:end -->")
    prompt = text[start:end]
    missing = [term for term in required[Path(filename).name] if term not in prompt]
    if missing:
        raise SystemExit(f"incomplete template prompt in {filename}: {missing}")
    if prompt.index("make verify") < prompt.index("PROJECT_CHECKS_CONFIGURED=1"):
        raise SystemExit(f"verification occurs before product checks in {filename}")
PY
}

test_active_docs_do_not_reference_repository_grill() {
  local references
  references="$(grep -R -n 'grill-with-docs' \
    "${ROOT_DIR}/README.md" "${ROOT_DIR}/README.zh-TW.md" \
    "${ROOT_DIR}/docs/skills.md" "${ROOT_DIR}/docs/skills.zh-TW.md" \
    "${ROOT_DIR}/docs/agents" || true)"
  [[ -z "${references}" ]] || fail "active documentation still references repository grill-with-docs"
}

test_project_check_success_propagates() {
  new_temp_dir
  local output
  write_valid_project_contract "${test_tmp}/project-contract.md"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${test_tmp}/project-checks.sh"
  if ! output="$(HARNESS_SKIP_TESTS=1 \
    HARNESS_PROJECT_CONTRACT="${test_tmp}/project-contract.md" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" \
    HARNESS_PROJECT_CHECKS="${test_tmp}/project-checks.sh" \
    bash "${ROOT_DIR}/scripts/harness/verify.sh" 2>&1)"; then
    fail "configured project checks should pass"
    return
  fi
  [[ "${output}" == *"Project checks: passed"* ]] || fail "missing successful project checks summary"
  [[ "${output}" == *"Overall: verification passed"* ]] || fail "missing complete verification summary"
  [[ "${output}" == *"HARNESS_VERIFICATION_STATUS=complete"* ]] || \
    fail "missing machine-readable complete status"
}

test_bootstrap_contract_prevents_complete_machine_status() {
  new_temp_dir
  local output
  local contract="${test_tmp}/project-contract.md"
  local checks="${test_tmp}/project-checks.sh"
  write_valid_project_contract "${contract}"
  sed -i.bak \
    -e 's/Status: complete/Status: bootstrap/' \
    -e '/Status: bootstrap/a\
- Bootstrap verification: `make verify`' \
    -e 's/Complete verification: `make verify`/Complete verification: unconfigured/' \
    "${contract}"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${checks}"
  output="$(HARNESS_SKIP_TESTS=1 HARNESS_PROJECT_CONTRACT="${contract}" \
    HARNESS_CONTRACT_ROOT="${test_tmp}" HARNESS_PROJECT_CHECKS="${checks}" \
    bash "${ROOT_DIR}/scripts/harness/verify.sh" 2>&1)"
  [[ "${output}" == *"Project checks: passed"* ]] || fail "configured checks did not pass"
  [[ "${output}" == *"Contract verification status: bootstrap"* ]] || fail "missing contract status"
  [[ "${output}" == *"HARNESS_VERIFICATION_STATUS=bootstrap"* ]] || \
    fail "bootstrap contract emitted a non-bootstrap machine status"
  [[ "${output}" != *"HARNESS_VERIFICATION_STATUS=complete"* ]] || \
    fail "bootstrap contract contradicted itself"
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

test_markdown_internal_anchors_resolve() {
  python3 - "${ROOT_DIR}" <<'PY'
from pathlib import Path
import re
import sys
from urllib.parse import unquote

root = Path(sys.argv[1])
link_pattern = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")


def heading_anchors(path):
    anchors = set()
    counts = {}
    in_fence = False
    for line in path.read_text().splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = re.match(r"^#{1,6}\s+(.+?)\s*#*\s*$", line)
        if not match:
            continue
        heading = re.sub(r"<[^>]+>", "", match.group(1)).replace("`", "").lower()
        slug = "".join(char for char in heading if char.isalnum() or char in " _-")
        slug = re.sub(r"\s+", "-", slug.strip())
        count = counts.get(slug, 0)
        counts[slug] = count + 1
        anchors.add(slug if count == 0 else f"{slug}-{count}")
    return anchors


failures = []
for source in sorted(root.rglob("*.md")):
    if ".git" in source.parts:
        continue
    for raw_target in link_pattern.findall(source.read_text()):
        if raw_target.startswith(("http://", "https://", "mailto:", "/")) or "#" not in raw_target:
            continue
        relative, raw_anchor = raw_target.split("#", 1)
        if not raw_anchor:
            continue
        target = source if not relative else (source.parent / unquote(relative)).resolve()
        if not target.is_file():
            continue
        anchor = unquote(raw_anchor).lower()
        if anchor not in heading_anchors(target):
            failures.append(f"{source.relative_to(root)} -> {raw_target}")

if failures:
    raise SystemExit("Broken Markdown heading anchors:\n" + "\n".join(failures))
PY
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

run_test "source project checks pass" test_source_project_checks_pass
run_test "verify reports complete source state" test_verify_reports_complete_source_state
run_test "valid Skill passes" test_valid_skill_passes
run_test "Skill name mismatch fails" test_skill_name_mismatch_fails
run_test "unfinished Skill placeholder fails" test_skill_placeholder_fails
run_test "invalid agent metadata fails" test_invalid_agent_metadata_fails
run_test "valid invocation policy values pass" test_invocation_policy_values_pass
run_test "invalid invocation policy fails" test_invalid_invocation_policy_fails
run_test "valid Project Contract passes" test_valid_project_contract_passes
run_test "folder Project Contract profile passes" test_folder_project_contract_profile_passes
run_test "Project Contract profiles remain strict" test_contract_profiles_remain_strict
run_test "folder Contract rejects version-control delivery modes" test_folder_contract_rejects_version_control_delivery_modes
run_test "missing Project Contract fails" test_missing_project_contract_fails
run_test "incomplete Project Contract fails" test_incomplete_project_contract_fails
run_test "duplicate Project Contract section fails" test_duplicate_project_contract_section_fails
run_test "Project Contract placeholder fails" test_project_contract_placeholder_fails
run_test "invalid delivery mode fails" test_invalid_delivery_mode_fails
run_test "unsafe workspace policy fails" test_unsafe_workspace_policy_fails
run_test "nonsensical verification command fails" test_nonsensical_verification_command_fails
run_test "unsafe contract path fails" test_unsafe_contract_path_fails
run_test "tracker configuration references pass" test_tracker_configuration_reference_passes
run_test "missing tracker configuration reference fails" test_missing_tracker_configuration_reference_fails
run_test "missing ticket backend configuration reference fails" test_missing_ticket_backend_configuration_reference_fails
run_test "unsafe tracker configuration reference fails" test_unsafe_tracker_configuration_reference_fails
run_test "malformed tracker configuration reference fails" test_malformed_tracker_configuration_reference_fails
run_test "verification configuration conflict fails" test_verification_configuration_conflict_fails
run_test "bootstrap Project Contract passes" test_bootstrap_contract_passes
run_test "misplaced Project Contract field fails" test_misplaced_contract_field_fails
run_test "bundled Skills are complete" test_bundled_skills_are_complete
run_test "onboarding leads with two entrypoints" test_onboarding_leads_with_two_entrypoints
run_test "template prompt configures before verification" test_template_prompt_covers_configuration_before_verification
run_test "active docs omit repository grill" test_active_docs_do_not_reference_repository_grill
run_test "successful project checks propagate" test_project_check_success_propagates
run_test "bootstrap Contract prevents complete machine status" test_bootstrap_contract_prevents_complete_machine_status
run_test "failed project checks propagate" test_project_check_failure_propagates
run_test "audit requires Codex CLI" test_audit_requires_codex
run_test "Markdown internal links resolve" test_markdown_internal_links_resolve
run_test "Markdown internal anchors resolve" test_markdown_internal_anchors_resolve
run_test "bilingual document pairs exist" test_bilingual_document_pairs_exist
run_test "README versions match VERSION" test_readmes_match_version

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ "${TESTS_FAILED}" -eq 0 ]]
