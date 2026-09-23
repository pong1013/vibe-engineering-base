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

preview_upgrade() {
  local cli="$1"
  local target="$2"
  shift 2
  python3 "${cli}" upgrade --target "${target}" "$@"
}

apply_upgrade_preview() {
  local cli="$1"
  local target="$2"
  local preview="$3"
  shift 3
  local token
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  python3 "${cli}" upgrade --target "${target}" "$@" --apply --plan-token "${token}"
}

write_evidence() {
  local path="$1"
  local content="$2"
  printf '%s\n' "${content}" > "${path}"
}

preview_learn() {
  python3 "${CLI}" learn --target "$1" --evidence-file "$2"
}

apply_learn_preview() {
  local target="$1"
  local evidence_file="$2"
  local preview="$3"
  local token
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  python3 "${CLI}" learn --target "${target}" --evidence-file "${evidence_file}" \
    --apply --plan-token "${token}"
}

new_upgrader() {
  upgrader_dir="${TEST_TEMP_ROOT}/upgrader-${TESTS_RUN}"
  cp -R "${ROOT_DIR}/skills/vibe-engineering" "${upgrader_dir}"
  printf '%s\n' '0.2.0' > "${upgrader_dir}/VERSION"
  printf '%s\n' '<!-- upgraded contract -->' >> "${upgrader_dir}/assets/contracts/folder.md"
}

snapshot_files() {
  local target="$1"
  find "${target}" -type f -not -path '*/.git/*' -print0 | sort -z | xargs -0 shasum -a 256
}

snapshot_tree() {
  local target="$1"
  python3 - "${target}" <<'PY'
import hashlib
import json
import os
import pathlib
import stat
import sys

root = pathlib.Path(sys.argv[1])
snapshot = []
for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix()):
    relative = path.relative_to(root).as_posix()
    metadata = path.lstat()
    mode = stat.S_IMODE(metadata.st_mode)
    if stat.S_ISLNK(metadata.st_mode):
        snapshot.append({"path": relative, "type": "symlink", "mode": mode, "target": os.readlink(path)})
    elif stat.S_ISDIR(metadata.st_mode):
        snapshot.append({"path": relative, "type": "directory", "mode": mode})
    elif stat.S_ISREG(metadata.st_mode):
        content = path.read_bytes()
        snapshot.append({
            "path": relative,
            "type": "file",
            "mode": mode,
            "size": len(content),
            "sha256": hashlib.sha256(content).hexdigest(),
        })
    else:
        snapshot.append({"path": relative, "type": "other", "mode": mode})
print(json.dumps(snapshot, sort_keys=True, separators=(",", ":")))
PY
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

test_upgrade_updates_clean_files_and_preserves_project_owned_skills() {
  new_project
  local setup_preview upgrade_preview applied custom_before custom_after
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  mkdir -p "${test_project}/.agents/skills/project-owned"
  printf '%s\n' 'project owned bytes' > "${test_project}/.agents/skills/project-owned/SKILL.md"
  custom_before="$(shasum -a 256 "${test_project}/.agents/skills/project-owned/SKILL.md")" || return
  new_upgrader

  upgrade_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${upgrade_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == ".agents/project-contract.md")')" == "replacement" ]] || \
    fail "clean changed managed file was not previewed as replacement"
  [[ "$(printf '%s' "${upgrade_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == ".agents/skills/harness-feedback/SKILL.md")')" == "unchanged" ]] || \
    fail "unchanged managed file was not reported"
  applied="$(apply_upgrade_preview "${upgrader_dir}/scripts/project_manager.py" "${test_project}" "${upgrade_preview}")" || return
  [[ "$(printf '%s' "${applied}" | json_value 'data["mode"]')" == "applied" ]] || \
    fail "upgrade did not report applied mode"
  grep -Fq '<!-- upgraded contract -->' "${test_project}/.agents/project-contract.md" || \
    fail "upgrade did not replace the clean managed file"
  [[ "$(json_value 'data["source_version"]' < "${test_project}/.agents/vibe-engineering/manifest.json")" == "0.2.0" ]] || \
    fail "upgrade did not update the manifest source version"
  custom_after="$(shasum -a 256 "${test_project}/.agents/skills/project-owned/SKILL.md")" || return
  [[ "${custom_before}" == "${custom_after}" ]] || fail "upgrade changed a project-owned Skill"

  local before_repeat repeat_preview after_repeat
  before_repeat="$(snapshot_files "${test_project}")" || return
  repeat_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${repeat_preview}" | json_value 'all(item["action"] == "unchanged" for item in data["operations"])')" == "True" ]] || \
    fail "current-version upgrade was not idempotent"
  apply_upgrade_preview "${upgrader_dir}/scripts/project_manager.py" "${test_project}" "${repeat_preview}" >/dev/null || return
  after_repeat="$(snapshot_files "${test_project}")" || return
  [[ "${before_repeat}" == "${after_repeat}" ]] || fail "current-version upgrade changed the project"
}

test_upgrade_conflict_requires_explicit_bounded_resolution() {
  new_project
  local setup_preview conflict_preview resolved_preview before_rejected after_rejected
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  printf '%s\n' 'local contract edit' >> "${test_project}/.agents/project-contract.md"
  new_upgrader

  before_rejected="$(snapshot_files "${test_project}")" || return
  conflict_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${conflict_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == ".agents/project-contract.md")')" == "conflict" ]] || \
    fail "modified file was not reported as a conflict"
  [[ "$(printf '%s' "${conflict_preview}" | json_value '"local contract edit" in next(item["diff"] for item in data["operations"] if item["path"] == ".agents/project-contract.md")')" == "True" ]] || \
    fail "conflict preview did not include a reviewable diff"
  if apply_upgrade_preview "${upgrader_dir}/scripts/project_manager.py" "${test_project}" "${conflict_preview}" >/dev/null 2>&1; then
    fail "unresolved conflict was applied"
    return
  fi
  after_rejected="$(snapshot_files "${test_project}")" || return
  [[ "${before_rejected}" == "${after_rejected}" ]] || fail "rejected conflict changed the target"

  resolved_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    --resolve-conflict .agents/project-contract.md)" || return
  [[ "$(printf '%s' "${resolved_preview}" | json_value 'next(item["resolution"] for item in data["operations"] if item["path"] == ".agents/project-contract.md")')" == "replace" ]] || \
    fail "explicit conflict resolution was not bounded in the preview"
  apply_upgrade_preview "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    "${resolved_preview}" --resolve-conflict .agents/project-contract.md >/dev/null || return
  ! grep -Fq 'local contract edit' "${test_project}/.agents/project-contract.md" || \
    fail "explicit replace resolution did not install packaged content"
}

test_upgrade_reports_missing_wrong_type_and_unsafe_paths() {
  new_project
  local setup_preview missing_preview wrong_type_preview
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  new_upgrader
  rm "${test_project}/.agents/skills/harness-feedback/SKILL.md"
  missing_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${missing_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == ".agents/skills/harness-feedback/SKILL.md")')" == "addition" ]] || \
    fail "missing managed file was not reported as an addition"

  mkdir "${test_project}/.agents/skills/harness-feedback/SKILL.md"
  wrong_type_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${wrong_type_preview}" | json_value 'next(item["reason"] for item in data["operations"] if item["path"] == ".agents/skills/harness-feedback/SKILL.md")')" == "wrong-type:directory" ]] || \
    fail "wrong-type managed path was not accurately reported"

  rm -rf "${test_project}/.agents/skills/harness-feedback/SKILL.md"
  ln -s "${TEST_TEMP_ROOT}" "${test_project}/.agents/skills/harness-feedback/SKILL.md"
  if preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" >/dev/null 2>&1; then
    fail "upgrade accepted an unsafe symlink path"
  fi
}

test_upgrade_write_failure_rolls_back_complete_target() {
  new_project
  local setup_preview upgrade_preview before after token
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  new_upgrader
  printf '%s\n' '# upgraded feedback' >> "${upgrader_dir}/assets/harness-feedback/SKILL.md"
  upgrade_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  token="$(printf '%s' "${upgrade_preview}" | json_value 'data["plan_token"]')" || return
  before="$(snapshot_tree "${test_project}")" || return
  if VIBE_ENGINEERING_TEST_FAIL_AFTER_WRITES=1 python3 "${upgrader_dir}/scripts/project_manager.py" \
    upgrade --target "${test_project}" --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "induced write failure unexpectedly succeeded"
    return
  fi
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "write failure did not roll back the complete target"
}

test_upgrade_token_and_resolutions_are_exactly_bound() {
  new_project
  local setup_preview conflict_preview resolved_preview token before after
  printf '%s\n' '# User preface' > "${test_project}/AGENTS.md"
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  printf '%s\n' 'local contract edit' >> "${test_project}/.agents/project-contract.md"
  new_upgrader
  conflict_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  token="$(printf '%s' "${conflict_preview}" | json_value 'data["plan_token"]')" || return
  before="$(snapshot_files "${test_project}")" || return
  if python3 "${upgrader_dir}/scripts/project_manager.py" upgrade --target "${test_project}" \
    --resolve-conflict .agents/project-contract.md --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "token without a resolution was accepted with an added resolution"
    return
  fi
  after="$(snapshot_files "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "resolution/token mismatch changed the target"

  if preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    --resolve-conflict AGENTS.md >/dev/null 2>&1; then
    fail "resolution for a non-conflict was accepted"
    return
  fi
  if preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    --resolve-conflict .agents/project-contract.md \
    --resolve-conflict .agents/project-contract.md >/dev/null 2>&1; then
    fail "duplicate conflict resolution was accepted"
    return
  fi
  if preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    --resolve-conflict ../outside >/dev/null 2>&1; then
    fail "unsafe conflict resolution was accepted"
    return
  fi

  resolved_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    --resolve-conflict .agents/project-contract.md)" || return
  printf '%s\n' 'changed after preview' >> "${test_project}/AGENTS.md"
  if apply_upgrade_preview "${upgrader_dir}/scripts/project_manager.py" "${test_project}" \
    "${resolved_preview}" --resolve-conflict .agents/project-contract.md >/dev/null 2>&1; then
    fail "stale upgrade token was accepted"
  fi
}

test_upgrade_preserves_agents_outside_block_and_conflicts_inside_block() {
  new_project
  local setup_preview clean_preview conflict_preview
  printf '%s\n' '# User preface' > "${test_project}/AGENTS.md"
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  new_upgrader
  printf '%s\n' 'User suffix.' >> "${test_project}/AGENTS.md"
  clean_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${clean_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == "AGENTS.md")')" == "unchanged" ]] || \
    fail "outside-block AGENTS edit created a conflict"

  python3 - "${test_project}/AGENTS.md" <<'PY' || return
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace("Keep reusable project workflows", "Keep altered project workflows"))
PY
  conflict_preview="$(preview_upgrade "${upgrader_dir}/scripts/project_manager.py" "${test_project}")" || return
  [[ "$(printf '%s' "${conflict_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == "AGENTS.md")')" == "conflict" ]] || \
    fail "inside-block AGENTS edit was not a conflict"
}

test_learn_keeps_one_off_choices_outside_durable_files() {
  new_project
  local setup_preview evidence_file before preview after
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/one-off-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "preference",
    "pattern_id": "prefer-short-status",
    "occurrences": [{"id": "turn-1"}],
    "explicit_standard": false,
    "guidance": ["Prefer short progress updates for this one task."]
  }'
  before="$(snapshot_tree "${test_project}")" || return
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  after="$(snapshot_tree "${test_project}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["decision"]')" == "no-durable-change" ]] || \
    fail "one-off preference was not rejected as durable learning"
  [[ "$(printf '%s' "${preview}" | json_value '"plan_token" in data')" == "False" ]] || \
    fail "one-off preference unexpectedly returned an apply token"
  [[ "${before}" == "${after}" ]] || fail "one-off preference changed durable files"
}

test_learn_rejects_boolean_evidence_schema_without_writes() {
  new_project
  local evidence_file before after output
  evidence_file="${TEST_TEMP_ROOT}/boolean-schema-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": true,
    "category": "preference",
    "pattern_id": "short-output",
    "occurrences": [{"id": "turn-8"}],
    "explicit_standard": false,
    "guidance": ["Keep the response short for this one task."]
  }'
  before="$(snapshot_tree "${test_project}")" || return
  if output="$(preview_learn "${test_project}" "${evidence_file}" 2>&1)"; then
    fail "boolean evidence schema version was accepted as integer version 1"
    return
  fi
  [[ "${output}" == *"unsupported schema"* ]] || fail "boolean schema refusal was unclear"
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "rejected boolean schema changed the target"
}

test_learn_rejects_forged_or_inconsistent_manifests_without_writes() {
  new_project
  local setup_preview evidence_file manifest valid_manifest mode before after output
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/manifest-validation-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "machine-checkable",
    "pattern_id": "verify-generated-files",
    "occurrences": [{"id": "review-71"}],
    "explicit_standard": false,
    "check_surface": "tests",
    "guidance": ["Reject generated files from the committed source directory."]
  }'
  manifest="${test_project}/.agents/vibe-engineering/manifest.json"
  valid_manifest="$(cat "${manifest}")"

  for mode in empty-managed boolean-schema missing-version wrong-project duplicate-capability unknown-capability bad-checksum wrong-scope; do
    printf '%s' "${valid_manifest}" > "${manifest}"
    python3 - "${manifest}" "${mode}" <<'PY' || return
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
mode = sys.argv[2]
data = json.loads(path.read_text())
if mode == "empty-managed":
    data["managed"] = []
elif mode == "boolean-schema":
    data["schema_version"] = True
elif mode == "missing-version":
    data.pop("source_version")
elif mode == "wrong-project":
    data["project_type"] = "repository" if data["project_type"] == "folder" else "folder"
elif mode == "duplicate-capability":
    data["capabilities"].append(data["capabilities"][0])
elif mode == "unknown-capability":
    data["capabilities"] = ["unknown-capability"]
elif mode == "bad-checksum":
    data["managed"][0]["sha256"] = "not-a-checksum"
elif mode == "wrong-scope":
    next(item for item in data["managed"] if item["path"] == "AGENTS.md")["scope"] = "file"
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    before="$(snapshot_tree "${test_project}")" || return
    if output="$(preview_learn "${test_project}" "${evidence_file}" 2>&1)"; then
      fail "learn accepted invalid installed manifest: ${mode}"
      return
    fi
    if [[ "${output}" != *"manifest"* && "${output}" != *"project type"* && \
      "${output}" != *"capability"* ]]; then
      fail "invalid manifest refusal was unclear: ${mode}"
      return
    fi
    after="$(snapshot_tree "${test_project}")" || return
    if [[ "${before}" != "${after}" ]]; then
      fail "rejected manifest changed the target: ${mode}"
      return
    fi
  done
}

test_learn_project_skill_requires_distinct_evidence_and_preview() {
  new_project
  local setup_preview evidence_file before preview after applied
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/skill-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "project-skill",
    "pattern_id": "release-notes-context",
    "occurrences": [{"id": "release-17"}],
    "explicit_standard": false,
    "skill_name": "write-release-notes",
    "trigger": "Use when preparing release notes for this project",
    "guidance": [
      "Read the release labels in docs/release-labels.md before grouping changes.",
      "Call out schema migrations under a dedicated operator action heading."
    ]
  }'
  before="$(snapshot_tree "${test_project}")" || return
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  after="$(snapshot_tree "${test_project}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["decision"]')" == "insufficient-evidence" ]] || \
    fail "one occurrence unexpectedly met the project Skill threshold"
  [[ "${before}" == "${after}" ]] || fail "insufficient evidence created durable state"

  python3 - "${evidence_file}" <<'PY' || return
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["occurrences"].append({"id": "release-18"})
path.write_text(json.dumps(data))
PY
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["decision"]')" == "propose-project-skill" ]] || \
    fail "two distinct occurrences did not propose a project Skill"
  [[ "$(printf '%s' "${preview}" | json_value 'data["operation"]["path"]')" == ".agents/skills/write-release-notes/SKILL.md" ]] || \
    fail "project Skill destination was incorrect"
  [[ ! -e "${test_project}/.agents/skills/write-release-notes" ]] || \
    fail "project Skill preview wrote files"
  applied="$(apply_learn_preview "${test_project}" "${evidence_file}" "${preview}")" || return
  [[ "$(printf '%s' "${applied}" | json_value 'data["mode"]')" == "applied" ]] || \
    fail "project Skill apply did not report applied mode"
  [[ -f "${test_project}/.agents/skills/write-release-notes/SKILL.md" ]] || \
    fail "project Skill was not created"
  HARNESS_SKILLS_DIR="${test_project}/.agents/skills" \
    bash "${ROOT_DIR}/scripts/harness/validate-skills.sh" >/dev/null || \
    fail "learn created an invalid project Skill"
  [[ ! -e "${test_project}/.agents/vibe-engineering/learning.json" ]] || \
    fail "learn persisted a hidden evidence ledger"
  ! grep -R -Fq 'release-17' "${test_project}/.agents" || \
    fail "learn persisted raw occurrence evidence"
}

test_learn_rejects_duplicate_occurrences_and_stale_or_conflicting_skill() {
  new_project
  local setup_preview evidence_file preview token before after conflict
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/skill-safety-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "project-skill",
    "pattern_id": "incident-handoff",
    "occurrences": [{"id": "incident-7"}, {"id": "incident-7"}],
    "explicit_standard": false,
    "skill_name": "incident-handoff",
    "trigger": "Use when handing an active incident to another operator",
    "guidance": [
      "Include the latest confirmed symptom and its observation timestamp.",
      "List attempted mitigations with their observed outcome and owner."
    ]
  }'
  before="$(snapshot_tree "${test_project}")" || return
  if preview_learn "${test_project}" "${evidence_file}" >/dev/null 2>&1; then
    fail "duplicate occurrence ids were accepted"
    return
  fi
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "rejected duplicate evidence changed the target"

  python3 - "${evidence_file}" <<'PY' || return
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["occurrences"] = [{"id": "incident-7"}]
data["explicit_standard"] = True
path.write_text(json.dumps(data))
PY
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  python3 - "${evidence_file}" <<'PY' || return
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data["guidance"][1] = "List attempted mitigations and name the next decision owner explicitly."
path.write_text(json.dumps(data))
PY
  if python3 "${CLI}" learn --target "${test_project}" --evidence-file "${evidence_file}" \
    --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "apply accepted evidence changed after preview"
    return
  fi
  [[ ! -e "${test_project}/.agents/skills/incident-handoff" ]] || \
    fail "stale learn apply wrote a project Skill"

  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  mkdir -p "${test_project}/.agents/skills/incident-handoff"
  printf '%s\n' 'project-owned content' > "${test_project}/.agents/skills/incident-handoff/SKILL.md"
  conflict="$(preview_learn "${test_project}" "${evidence_file}")" || return
  [[ "$(printf '%s' "${conflict}" | json_value 'data["operation"]["action"]')" == "conflict" ]] || \
    fail "existing same-name project Skill was not a reviewable conflict"
  [[ "$(printf '%s' "${conflict}" | json_value '"plan_token" in data')" == "False" ]] || \
    fail "conflicting project Skill returned an apply token"
}

test_learn_binds_destination_state_and_rolls_back_partial_skill() {
  new_project
  local setup_preview evidence_file preview token before after rollback_preview rollback_token
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/skill-binding-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "project-skill",
    "pattern_id": "deploy-handoff",
    "occurrences": [{"id": "deploy-21"}],
    "explicit_standard": true,
    "skill_name": "deploy-handoff",
    "trigger": "Use when handing a production deployment to another operator",
    "guidance": [
      "Record the deployed revision and the environment that received it.",
      "List remaining checks with their owner and expected completion time."
    ]
  }'
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  token="$(printf '%s' "${preview}" | json_value 'data["plan_token"]')" || return
  mkdir -p "${test_project}/.agents/skills/deploy-handoff"
  printf '%s\n' 'project-owned content' > \
    "${test_project}/.agents/skills/deploy-handoff/SKILL.md"
  if python3 "${CLI}" learn --target "${test_project}" --evidence-file "${evidence_file}" \
    --apply --plan-token "${token}" >/dev/null 2>&1; then
    fail "learn token was accepted after destination state changed"
    return
  fi
  [[ "$(cat "${test_project}/.agents/skills/deploy-handoff/SKILL.md")" == "project-owned content" ]] || \
    fail "stale learn apply replaced project-owned content"

  rm -rf -- "${test_project}/.agents/skills/deploy-handoff"
  rollback_preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  rollback_token="$(printf '%s' "${rollback_preview}" | json_value 'data["plan_token"]')" || return
  before="$(snapshot_tree "${test_project}")" || return
  if VIBE_ENGINEERING_TEST_FAIL_AFTER_WRITES=1 python3 "${CLI}" learn \
    --target "${test_project}" --evidence-file "${evidence_file}" \
    --apply --plan-token "${rollback_token}" >/dev/null 2>&1; then
    fail "induced learn write failure unexpectedly succeeded"
    return
  fi
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "learn write failure did not restore the target"
}

test_learn_rejects_unsafe_destination_and_secret_evidence() {
  new_project
  local setup_preview evidence_file outside before after output
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/unsafe-learn-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "machine-checkable",
    "pattern_id": "verify-cache",
    "occurrences": [{"id": "review-22"}],
    "explicit_standard": false,
    "check_surface": "tests",
    "guidance": ["Reject generated cache files from the committed project tree."]
  }'
  outside="${TEST_TEMP_ROOT}/outside-${TESTS_RUN}"
  mkdir -p "${outside}"
  mkdir -p "${test_project}/.agents/vibe-engineering/proposals"
  ln -s "${outside}" "${test_project}/.agents/vibe-engineering/proposals/checks"
  before="$(snapshot_tree "${test_project}")" || return
  if output="$(preview_learn "${test_project}" "${evidence_file}" 2>&1)"; then
    fail "learn accepted a symbolic-link destination"
    return
  fi
  [[ "${output}" == *"symbolic link"* ]] || fail "unsafe learn path error was unclear"
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "rejected learn destination changed the target"

  rm "${test_project}/.agents/vibe-engineering/proposals/checks"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "repository-guidance",
    "pattern_id": "credential-note",
    "occurrences": [{"id": "review-23"}],
    "explicit_standard": false,
    "guidance": ["Use api_key=super-secret-value for the integration check."]
  }'
  if preview_learn "${test_project}" "${evidence_file}" >/dev/null 2>&1; then
    fail "learn accepted evidence containing an apparent secret"
  fi
  ! grep -R -Fq 'super-secret-value' "${test_project}/.agents" || \
    fail "learn persisted a secret from rejected evidence"
}

test_learn_routes_machine_checks_to_reviewable_proposals() {
  new_project
  local setup_preview evidence_file preview applied proposal
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/machine-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "machine-checkable",
    "pattern_id": "generated-files-ignored",
    "occurrences": [{"id": "review-41"}],
    "explicit_standard": false,
    "check_surface": "harness-checks",
    "guidance": ["Fail verification when generated cache files are tracked under build/cache."]
  }'
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["decision"]')" == "propose-machine-check" ]] || \
    fail "machine-checkable evidence was not routed to a check proposal"
  [[ "$(printf '%s' "${preview}" | json_value 'data["operation"]["path"]')" == ".agents/vibe-engineering/proposals/checks/generated-files-ignored.md" ]] || \
    fail "machine-check proposal destination was not bounded"
  [[ ! -e "${test_project}/.agents/vibe-engineering/proposals" ]] || \
    fail "machine-check preview wrote a proposal"
  applied="$(apply_learn_preview "${test_project}" "${evidence_file}" "${preview}")" || return
  proposal="${test_project}/.agents/vibe-engineering/proposals/checks/generated-files-ignored.md"
  [[ -f "${proposal}" ]] || fail "machine-check proposal was not written"
  grep -Fq 'Target surface: `harness-checks`' "${proposal}" || \
    fail "machine-check proposal omitted its selected check surface"
  grep -Fq 'generated cache files' "${proposal}" || \
    fail "machine-check proposal omitted the required behavior"
  [[ ! -e "${test_project}/.agents/vibe-engineering/proposals/checks/generated-files-ignored.py" ]] || \
    fail "learn fabricated executable check code"
}

test_learn_routes_repository_guidance_inside_managed_block() {
  new_project
  printf '%s\n' '# User instructions' 'Preserve this line.' > "${test_project}/AGENTS.md"
  local setup_preview evidence_file preview status_output upgrade_preview
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  evidence_file="${TEST_TEMP_ROOT}/guidance-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "repository-guidance",
    "pattern_id": "schema-docs",
    "occurrences": [{"id": "review-52"}],
    "explicit_standard": false,
    "guidance": ["Update docs/schema.md whenever a persisted schema field changes."]
  }'
  preview="$(preview_learn "${test_project}" "${evidence_file}")" || return
  [[ "$(printf '%s' "${preview}" | json_value 'data["decision"]')" == "propose-repository-guidance" ]] || \
    fail "repository lesson was not routed to managed guidance"
  [[ "$(printf '%s' "${preview}" | json_value 'data["operation"]["path"]')" == "AGENTS.md" ]] || \
    fail "repository guidance targeted an unexpected file"
  apply_learn_preview "${test_project}" "${evidence_file}" "${preview}" >/dev/null || return
  grep -Fq 'Preserve this line.' "${test_project}/AGENTS.md" || \
    fail "repository guidance replaced user-owned AGENTS content"
  python3 - "${test_project}/AGENTS.md" <<'PY' || return
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
start = text.index("<!-- vibe-engineering:start -->")
learned_start = text.index("<!-- vibe-engineering:learned:start -->")
guidance = text.index("Update docs/schema.md whenever a persisted schema field changes.")
learned_end = text.index("<!-- vibe-engineering:learned:end -->")
end = text.index("<!-- vibe-engineering:end -->")
assert start < learned_start < guidance < learned_end < end
PY
  status_output="$(python3 "${CLI}" status --target "${test_project}")" || return
  [[ "$(printf '%s' "${status_output}" | json_value 'data["status"]')" == "current" ]] || \
    fail "learned repository guidance left the manifest modified"
  upgrade_preview="$(preview_upgrade "${CLI}" "${test_project}")" || return
  [[ "$(printf '%s' "${upgrade_preview}" | json_value 'next(item["action"] for item in data["operations"] if item["path"] == "AGENTS.md")')" == "unchanged" ]] || \
    fail "upgrade did not preserve learned repository guidance"
}

test_learn_does_not_replace_modified_managed_guidance() {
  new_project
  local setup_preview evidence_file before after output
  setup_preview="$(preview_setup "${test_project}")" || return
  apply_preview "${test_project}" "${setup_preview}" >/dev/null || return
  python3 - "${test_project}/AGENTS.md" <<'PY' || return
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace(
    "Keep reusable project workflows in `.agents/skills/`.",
    "Keep locally customized project workflows in `.agents/skills/`.",
))
PY
  evidence_file="${TEST_TEMP_ROOT}/modified-guidance-${TESTS_RUN}.json"
  write_evidence "${evidence_file}" '{
    "schema_version": 1,
    "category": "repository-guidance",
    "pattern_id": "schema-docs",
    "occurrences": [{"id": "review-61"}],
    "explicit_standard": false,
    "guidance": ["Update docs/schema.md whenever a persisted schema field changes."]
  }'
  before="$(snapshot_tree "${test_project}")" || return
  if output="$(preview_learn "${test_project}" "${evidence_file}" 2>&1)"; then
    fail "learn accepted locally modified managed guidance"
    return
  fi
  [[ "${output}" == *"locally modified"* ]] || \
    fail "modified managed guidance refusal was unclear"
  after="$(snapshot_tree "${test_project}")" || return
  [[ "${before}" == "${after}" ]] || fail "rejected guidance learning changed the target"
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
run_test "upgrade updates clean files and preserves project-owned Skills" test_upgrade_updates_clean_files_and_preserves_project_owned_skills
run_test "upgrade conflicts require explicit bounded resolution" test_upgrade_conflict_requires_explicit_bounded_resolution
run_test "upgrade reports missing, wrong-type, and unsafe paths" test_upgrade_reports_missing_wrong_type_and_unsafe_paths
run_test "upgrade write failure rolls back the complete target" test_upgrade_write_failure_rolls_back_complete_target
run_test "upgrade tokens and resolutions are exactly bound" test_upgrade_token_and_resolutions_are_exactly_bound
run_test "upgrade preserves AGENTS outside its managed block" test_upgrade_preserves_agents_outside_block_and_conflicts_inside_block
run_test "learn keeps one-off choices outside durable files" test_learn_keeps_one_off_choices_outside_durable_files
run_test "learn rejects boolean evidence schema versions" test_learn_rejects_boolean_evidence_schema_without_writes
run_test "learn rejects forged and inconsistent manifests" test_learn_rejects_forged_or_inconsistent_manifests_without_writes
run_test "learn project Skill requires distinct evidence and preview" test_learn_project_skill_requires_distinct_evidence_and_preview
run_test "learn rejects duplicate, stale, and conflicting Skill evidence" test_learn_rejects_duplicate_occurrences_and_stale_or_conflicting_skill
run_test "learn binds destinations and rolls back partial Skill writes" test_learn_binds_destination_state_and_rolls_back_partial_skill
run_test "learn rejects unsafe destinations and secret evidence" test_learn_rejects_unsafe_destination_and_secret_evidence
run_test "learn routes machine checks to reviewable proposals" test_learn_routes_machine_checks_to_reviewable_proposals
run_test "learn routes repository guidance inside the managed block" test_learn_routes_repository_guidance_inside_managed_block
run_test "learn preserves locally modified managed guidance" test_learn_does_not_replace_modified_managed_guidance

echo "${TESTS_RUN} vibe-engineering tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]
