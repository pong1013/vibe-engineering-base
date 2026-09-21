#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT_DIR}/skills/vibe-engineering/scripts/project_manager.py"
TESTS_RUN=0
TESTS_FAILED=0
TEST_TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vibe-engineering-skill-test.XXXXXX")"

cleanup() {
  if [[ -d "${TEST_TEMP_ROOT}" && "$(basename "${TEST_TEMP_ROOT}")" == vibe-engineering-skill-test.* ]]; then
    rm -rf -- "${TEST_TEMP_ROOT}"
  fi
}
trap cleanup EXIT

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

new_project() {
  test_project="${TEST_TEMP_ROOT}/project-${TESTS_RUN}"
  mkdir -p "${test_project}"
}

json_value() {
  local expression="$1"
  python3 -c "import json,sys; data=json.load(sys.stdin); print(${expression})"
}

preview_setup() {
  python3 "${CLI}" setup --target "$1"
}

apply_preview() {
  local target="$1"
  local preview="$2"
  local token
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  python3 "${CLI}" setup --target "${target}" --apply --plan-token "${token}"
}

snapshot_files() {
  local target="$1"
  find "${target}" -type f -not -path '*/.git/*' -print0 | sort -z | xargs -0 shasum -a 256
}

test_skill_package_is_valid() {
  HARNESS_SKILLS_DIR="${ROOT_DIR}/skills" \
    bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null
}

test_setup_preview_is_read_only() {
  new_project
  printf '%s\n' '# Existing instructions' > "${test_project}/AGENTS.md"

  local preview token
  preview="$(python3 "${CLI}" setup --target "${test_project}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return

  [[ -n "${token}" ]] || fail "preview did not return a plan token"
  [[ ! -e "${test_project}/.agents" ]] || fail "preview wrote managed files"
  [[ "$(cat "${test_project}/AGENTS.md")" == '# Existing instructions' ]] || \
    fail "preview changed AGENTS.md"
}

test_copied_skill_subtree_is_self_contained() {
  new_project
  local installed="${TEST_TEMP_ROOT}/installed-${TESTS_RUN}" preview
  cp -R "${ROOT_DIR}/skills/vibe-engineering" "${installed}"
  preview="$(python3 "${installed}/scripts/project_manager.py" setup --target "${test_project}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["source_version"]')" == "0.1.0" ]] || \
    fail "copied Skill subtree could not load its packaged version"
  apply_preview_with_cli() {
    local token
    token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
    python3 "${installed}/scripts/project_manager.py" setup --target "${test_project}" \
      --apply --plan-token "${token}"
  }
  apply_preview_with_cli >/dev/null || return
  [[ -f "${test_project}/.agents/project-contract.md" ]] || \
    fail "copied Skill subtree did not install its packaged assets"
  HARNESS_SKILLS_DIR="${test_project}/.agents/skills" \
    bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null || \
    fail "copied Skill subtree installed an invalid project Skill"
}

test_setup_applies_manifest_and_is_idempotent() {
  new_project
  local original_agents
  original_agents=$'# Existing instructions\nKeep this exact line.  \n\n\n'
  printf '%s' "${original_agents}" > "${test_project}/AGENTS.md"
  git -C "${test_project}" init -q

  local preview applied before_repeat after_repeat second_preview
  preview="$(preview_setup "${test_project}")" || return
  applied="$(apply_preview "${test_project}" "${preview}")" || return

  [[ "$(printf '%s' "${applied}" | json_value 'data["mode"]')" == "applied" ]] || \
    fail "apply did not report applied mode"
  grep -Fq 'Keep this exact line.' "${test_project}/AGENTS.md" || \
    fail "setup did not preserve existing AGENTS.md content"
  python3 - "${test_project}/AGENTS.md" "${original_agents}" <<'PY' || return
import pathlib, sys
assert pathlib.Path(sys.argv[1]).read_text().startswith(sys.argv[2])
PY
  [[ "$(grep -Fc '<!-- vibe-engineering:start -->' "${test_project}/AGENTS.md")" -eq 1 ]] || \
    fail "setup did not create exactly one managed block"
  [[ -f "${test_project}/.agents/project-contract.md" ]] || fail "missing Project Contract"
  [[ -f "${test_project}/.agents/skills/harness-feedback/SKILL.md" ]] || \
    fail "missing harness-feedback Skill"
  [[ -f "${test_project}/.agents/skills/harness-feedback/agents/openai.yaml" ]] || \
    fail "missing harness-feedback metadata"

  python3 - "${test_project}/.agents/vibe-engineering/manifest.json" <<'PY' || return
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert manifest["source_version"] == "0.1.0"
assert manifest["project_type"] == "repository"
assert manifest["capabilities"] == ["harness", "harness-feedback"]
assert {item["path"] for item in manifest["managed"]} == {
    "AGENTS.md", ".agents/project-contract.md",
    ".agents/skills/harness-feedback/SKILL.md",
    ".agents/skills/harness-feedback/agents/openai.yaml",
}
assert all(len(item["sha256"]) == 64 for item in manifest["managed"])
assert "secret" not in json.dumps(manifest).lower()
PY

  before_repeat="$(snapshot_files "${test_project}")" || return
  second_preview="$(preview_setup "${test_project}")" || return
  [[ "$(printf '%s' "${second_preview}" | json_value 'all(item["action"] == "unchanged" for item in data["operations"])')" == "True" ]] || \
    fail "repeated setup preview was not idempotent"
  apply_preview "${test_project}" "${second_preview}" >/dev/null || return
  after_repeat="$(snapshot_files "${test_project}")" || return
  [[ "${before_repeat}" == "${after_repeat}" ]] || fail "repeated setup changed managed files"
}

test_folder_setup_omits_repository_concepts() {
  new_project
  local preview applied output_file
  preview="$(preview_setup "${test_project}")" || return
  applied="$(apply_preview "${test_project}" "${preview}")" || return
  output_file="${TEST_TEMP_ROOT}/folder-output-${TESTS_RUN}.txt"
  {
    printf '%s\n' "${preview}" "${applied}"
    cat "${test_project}/AGENTS.md"
    cat "${test_project}/.agents/project-contract.md"
    cat "${test_project}/.agents/skills/harness-feedback/SKILL.md"
    cat "${test_project}/.agents/vibe-engineering/manifest.json"
  } > "${output_file}"
  if grep -Eiq '(^|[^[:alnum:]_])(git|ci|branch|commit|pr)([^[:alnum:]_]|$)' "${output_file}"; then
    fail "folder setup emitted repository-only concepts"
  fi
}

test_apply_rejects_stale_plan() {
  new_project
  printf '%s\n' '# Initial' > "${test_project}/AGENTS.md"
  local preview token output
  preview="$(preview_setup "${test_project}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  printf '%s\n' 'Changed after preview.' >> "${test_project}/AGENTS.md"
  if output="$(python3 "${CLI}" setup --target "${test_project}" --apply --plan-token "${token}" 2>&1)"; then
    fail "apply accepted a stale plan token"
    return
  fi
  [[ "${output}" == *"state changed after preview"* ]] || fail "stale plan error was unclear"
  [[ ! -e "${test_project}/.agents" ]] || fail "stale apply wrote partial setup"
}

test_plan_token_cannot_cross_targets_or_replay() {
  new_project
  local first_project="${test_project}" second_project preview token
  second_project="${TEST_TEMP_ROOT}/second-${TESTS_RUN}"
  mkdir -p "${second_project}"
  preview="$(preview_setup "${first_project}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return

  if python3 "${CLI}" setup --target "${second_project}" --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "plan token was accepted for a different canonical target"
    return
  fi
  [[ ! -e "${second_project}/.agents" ]] || fail "cross-target apply wrote files"

  python3 "${CLI}" setup --target "${first_project}" --apply --plan-token "${token}" >/dev/null || return
  if python3 "${CLI}" setup --target "${first_project}" --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "plan token could be replayed after project state changed"
  fi
}

test_plan_token_rejects_project_type_change() {
  new_project
  local preview token
  preview="$(preview_setup "${test_project}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["project_type"]')" == "folder" ]] || \
    fail "test preview did not begin as a plain folder"
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  git -C "${test_project}" init -q

  if python3 "${CLI}" setup --target "${test_project}" --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "folder plan token was accepted after target became a repository"
    return
  fi
  [[ ! -e "${test_project}/AGENTS.md" ]] || fail "rejected project-type change wrote AGENTS.md"
  [[ ! -e "${test_project}/.agents" ]] || fail "rejected project-type change wrote managed files"
}

assert_rejected_target() {
  local target="$1"
  local expected="$2"
  local output
  if output="$(python3 "${CLI}" setup --target "${target}" 2>&1)"; then
    fail "unsafe target was accepted: ${target}"
    return
  fi
  [[ "${output}" == *"${expected}"* ]] || fail "missing unsafe-target reason: ${expected}"
}

test_unsafe_targets_are_rejected() {
  new_project
  local linked="${TEST_TEMP_ROOT}/linked-${TESTS_RUN}"
  ln -s "${test_project}" "${linked}"
  assert_rejected_target / "filesystem root" || return
  assert_rejected_target "${HOME}" "home directory" || return
  assert_rejected_target "${test_project}/../$(basename "${test_project}")" "parent-directory traversal" || return
  assert_rejected_target "${linked}" "symbolic link"
}

test_symlink_write_target_is_rejected() {
  new_project
  mkdir -p "${test_project}/.agents" "${TEST_TEMP_ROOT}/outside-${TESTS_RUN}"
  : > "${TEST_TEMP_ROOT}/outside-${TESTS_RUN}/contract.md"
  ln -s "${TEST_TEMP_ROOT}/outside-${TESTS_RUN}/contract.md" \
    "${test_project}/.agents/project-contract.md"
  assert_rejected_target "${test_project}" "managed write path must not use a symbolic link" || return
  [[ ! -e "${test_project}/AGENTS.md" ]] || fail "validation failure wrote AGENTS.md"
}

test_symlink_ancestor_is_rejected() {
  new_project
  local outside="${TEST_TEMP_ROOT}/ancestor-outside-${TESTS_RUN}"
  mkdir -p "${outside}"
  ln -s "${outside}" "${test_project}/.agents"
  assert_rejected_target "${test_project}" "managed write path must not use a symbolic link" || return
  [[ ! -e "${test_project}/AGENTS.md" ]] || fail "ancestor validation failure wrote AGENTS.md"
}

test_apply_validation_failure_leaves_no_partial_setup() {
  new_project
  local preview token outside
  preview="$(preview_setup "${test_project}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  outside="${TEST_TEMP_ROOT}/late-outside-${TESTS_RUN}.yaml"
  : > "${outside}"
  mkdir -p "${test_project}/.agents/skills/harness-feedback/agents"
  ln -s "${outside}" "${test_project}/.agents/skills/harness-feedback/agents/openai.yaml"
  if python3 "${CLI}" setup --target "${test_project}" --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "apply accepted a symlink introduced after preview"
    return
  fi
  [[ ! -e "${test_project}/AGENTS.md" ]] || fail "failed apply wrote AGENTS.md"
  [[ ! -e "${test_project}/.agents/project-contract.md" ]] || \
    fail "failed apply wrote the Project Contract"
  [[ ! -e "${test_project}/.agents/vibe-engineering/manifest.json" ]] || \
    fail "failed apply wrote the manifest"
}

test_malformed_managed_markers_fail_closed() {
  new_project
  printf '%s\n' '# Existing' '<!-- vibe-engineering:start -->' 'broken block' \
    > "${test_project}/AGENTS.md"
  assert_rejected_target "${test_project}" "invalid Vibe Engineering managed block" || return
  [[ ! -e "${test_project}/.agents" ]] || fail "malformed markers caused partial setup"
  printf '%s\n' \
    '<!-- vibe-engineering:start -->' '<!-- vibe-engineering:end -->' \
    '<!-- vibe-engineering:start -->' '<!-- vibe-engineering:end -->' \
    > "${test_project}/AGENTS.md"
  assert_rejected_target "${test_project}" "invalid Vibe Engineering managed block" || return
  [[ ! -e "${test_project}/.agents" ]] || fail "duplicate markers caused partial setup"
}

test_capability_selection_is_recorded() {
  new_project
  local preview token
  preview="$(python3 "${CLI}" setup --target "${test_project}" --capability harness)" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  python3 "${CLI}" setup --target "${test_project}" --capability harness \
    --apply --plan-token "${token}" >/dev/null || return
  [[ ! -e "${test_project}/.agents/skills/harness-feedback" ]] || \
    fail "unselected capability was installed"
  python3 - "${test_project}/.agents/vibe-engineering/manifest.json" <<'PY'
import json, pathlib, sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert manifest["capabilities"] == ["harness"]
PY
}

test_status_reports_states_without_writing() {
  new_project
  local preview current_status after_unmanaged before_status after_status changed_status upgraded_status
  preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${preview}" >/dev/null || return

  current_status="$(python3 "${CLI}" status --target "${test_project}")" || return
  [[ "$(printf '%s' "${current_status}" | json_value 'data["status"]')" == "current" ]] || \
    fail "fresh setup was not current"

  printf '%s\n' 'User-owned instruction.' >> "${test_project}/AGENTS.md"
  after_unmanaged="$(python3 "${CLI}" status --target "${test_project}")" || return
  [[ "$(printf '%s' "${after_unmanaged}" | json_value 'data["status"]')" == "current" ]] || \
    fail "user-owned AGENTS.md content affected managed-block status"

  printf '%s\n' 'locally changed' >> "${test_project}/.agents/project-contract.md"
  rm "${test_project}/.agents/skills/harness-feedback/SKILL.md"
  changed_status="$(python3 "${CLI}" status --target "${test_project}")" || return
  [[ "$(printf '%s' "${changed_status}" | json_value 'next(item["status"] for item in data["managed"] if item["path"] == ".agents/project-contract.md")')" == "modified" ]] || \
    fail "status did not report a modified file"
  [[ "$(printf '%s' "${changed_status}" | json_value 'next(item["status"] for item in data["managed"] if item["path"] == ".agents/skills/harness-feedback/SKILL.md")')" == "missing" ]] || \
    fail "status did not report a missing file"

  python3 - "${test_project}/.agents/vibe-engineering/manifest.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
manifest = json.loads(path.read_text())
manifest["source_version"] = "0.0.0"
path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
PY
  before_status="$(snapshot_files "${test_project}")" || return
  upgraded_status="$(python3 "${CLI}" status --target "${test_project}")" || return
  after_status="$(snapshot_files "${test_project}")" || return
  [[ "$(printf '%s' "${upgraded_status}" | json_value 'data["status"]')" == "upgrade-available" ]] || \
    fail "status did not report an available upgrade"
  [[ "${before_status}" == "${after_status}" ]] || fail "status wrote to the project"
}

run_test "Skill package is valid" test_skill_package_is_valid
run_test "setup preview is read-only" test_setup_preview_is_read_only
run_test "copied Skill subtree is self-contained" test_copied_skill_subtree_is_self_contained
run_test "setup applies a manifest and is idempotent" test_setup_applies_manifest_and_is_idempotent
run_test "folder setup omits repository concepts" test_folder_setup_omits_repository_concepts
run_test "apply rejects a stale plan" test_apply_rejects_stale_plan
run_test "plan token cannot cross targets or replay" test_plan_token_cannot_cross_targets_or_replay
run_test "plan token rejects project type changes" test_plan_token_rejects_project_type_change
run_test "unsafe targets are rejected" test_unsafe_targets_are_rejected
run_test "symlink write targets are rejected" test_symlink_write_target_is_rejected
run_test "symlink ancestors are rejected" test_symlink_ancestor_is_rejected
run_test "failed validation leaves no partial setup" test_apply_validation_failure_leaves_no_partial_setup
run_test "malformed managed markers fail closed" test_malformed_managed_markers_fail_closed
run_test "capability selection is recorded" test_capability_selection_is_recorded
run_test "status reports states without writing" test_status_reports_states_without_writing

echo "${TESTS_RUN} vibe-engineering tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]
