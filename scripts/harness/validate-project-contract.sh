#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT_FILE="${HARNESS_PROJECT_CONTRACT:-${ROOT_DIR}/.agents/project-contract.md}"
CONTRACT_ROOT="${HARNESS_CONTRACT_ROOT:-${ROOT_DIR}}"
PROJECT_CHECKS_FILE="${HARNESS_PROJECT_CHECKS:-${CONTRACT_ROOT}/scripts/harness/project-checks.sh}"
CONTRACT_PROFILE="${HARNESS_CONTRACT_PROFILE:-repository}"
expected_sections=(
  "Verification"
  "Knowledge"
  "Work artifacts"
  "Workspace"
  "Delivery"
)

die() {
  echo "Project Contract error: $* (${CONTRACT_FILE})" >&2
  exit 1
}

case "${CONTRACT_PROFILE}" in
  repository|folder) ;;
  *) die "HARNESS_CONTRACT_PROFILE must be 'repository' or 'folder'" ;;
esac

field_value() {
  local section="$1"
  local label="$2"
  local count
  local values
  values="$(awk -v section="${section}" -v label="${label}" '
    $0 == "## " section { inside = 1; next }
    /^## / { inside = 0 }
    inside && index($0, "- " label ": ") == 1 {
      sub("^- " label ": ", "")
      print
    }
  ' "${CONTRACT_FILE}")"
  count="$(printf '%s\n' "${values}" | awk 'NF { count++ } END { print count + 0 }')"
  [[ "${count}" -eq 1 ]] || die "section '${section}' must contain exactly one '${label}' field"
  printf '%s\n' "${values}"
}

validate_section_fields() {
  local section="$1"
  local allowed="$2"
  local unknown
  unknown="$(awk -v section="${section}" -v allowed="${allowed}" '
    BEGIN {
      count = split(allowed, labels, "|")
      for (i = 1; i <= count; i++) valid[labels[i]] = 1
    }
    $0 == "## " section { inside = 1; next }
    /^## / { inside = 0 }
    inside && /^- [^:]+: / {
      field = $0
      sub(/^- /, "", field)
      sub(/: .*/, "", field)
      if (!(field in valid)) print field
    }
  ' "${CONTRACT_FILE}")"
  [[ -z "${unknown}" ]] || die "section '${section}' contains unsupported field(s): $(printf '%s' "${unknown}" | tr '\n' ',')"
}

validate_relative_path() {
  local section="$1"
  local label="$2"
  local value
  value="$(field_value "${section}" "${label}")"
  [[ "${value}" == "unconfigured" ]] && return
  [[ "${value}" =~ ^\`[^\`]+\`$ ]] || die "${label} must be 'unconfigured' or one backtick-wrapped relative path"
  value="${value#\`}"
  value="${value%\`}"
  [[ "${value}" =~ ^[A-Za-z0-9._/-]+$ ]] || die "${label} contains unsupported path characters"
  [[ "${value}" != /* && "${value}" != ".." && "${value}" != ../* && "${value}" != */../* && "${value}" != */.. ]] || \
    die "${label} must remain inside the repository"
}

validate_repo_path_value() {
  local label="$1"
  local value="$2"
  [[ "${value}" =~ ^\`[^\`]+\`$ ]] || die "${label} must contain one backtick-wrapped relative path"
  value="${value#\`}"
  value="${value%\`}"
  [[ "${value}" =~ ^[A-Za-z0-9._/-]+$ ]] || die "${label} contains unsupported path characters"
  [[ "${value}" != /* && "${value}" != ".." && "${value}" != ../* && "${value}" != */../* && "${value}" != */.. ]] || \
    die "${label} must remain inside the repository"
}

validate_configuration_reference() {
  local label="$1"
  local value="$2"
  local path
  local current
  local part
  local parts
  validate_repo_path_value "${label}" "${value}"
  path="${value#\`}"
  path="${path%\`}"
  current="${CONTRACT_ROOT}"
  [[ ! -L "${current}" ]] || die "${label} must not use a symbolic link: ${path}"
  IFS='/' read -r -a parts <<< "${path}"
  for part in "${parts[@]}"; do
    current="${current}/${part}"
    [[ ! -L "${current}" ]] || die "${label} must not use a symbolic link: ${path}"
  done
  [[ -f "${CONTRACT_ROOT}/${path}" ]] || die "${label} file not found: ${path}"
}

validate_artifact_location() {
  local label="$1"
  local value="$2"
  [[ "${value}" == "unconfigured" ]] && return
  if [[ "${value}" == "configured by \`"*"\`" ]]; then
    value="${value#configured by }"
    validate_configuration_reference "${label} configuration reference" "${value}"
    return
  fi
  validate_repo_path_value "${label}" "${value}"
}

validate_command() {
  local label="$1"
  local value="$2"
  local first_token
  [[ "${value}" =~ ^\`[^\`]+\`$ ]] || die "${label} must be one backtick-wrapped command"
  value="${value#\`}"
  value="${value%\`}"
  IFS=$' \t' read -r first_token _ <<< "${value}"
  case "${first_token}" in
    true|false|:|yes|no) die "${label} is not an executable verification entrypoint" ;;
  esac
  [[ "${value}" =~ ^[A-Za-z0-9./:+_-]+([[:space:]][A-Za-z0-9./:=,@%+_-]+)*$ ]] || \
    die "${label} must be a direct command without shell control operators"
}

is_valid_git_branch_name() {
  local branch="$1"
  local component
  local components
  [[ "${branch}" =~ ^[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "${branch}" != "HEAD" ]] || return 1
  [[ "${branch}" != /* && "${branch}" != */ && "${branch}" != -* ]] || return 1
  [[ "${branch}" != *..* && "${branch}" != *//* ]] || return 1
  IFS='/' read -r -a components <<< "${branch}"
  for component in "${components[@]}"; do
    [[ -n "${component}" && "${component}" != .* && "${component}" != *. && \
       "${component}" != *.lock ]] || return 1
  done
}

is_valid_feature_branch_pattern() {
  local pattern="$1"
  local without_first
  [[ "${pattern}" =~ ^[A-Za-z0-9._/*-]+$ ]] || return 1
  without_first="${pattern/\*/}"
  [[ "${without_first}" != *\** ]] || return 1
  is_valid_git_branch_name "${pattern//\*/x}"
}

is_valid_remote_name() {
  local remote="$1"
  [[ "${remote}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || return 1
  [[ "${remote}" != *..* && "${remote}" != *. && "${remote}" != *.lock ]]
}

[[ -f "${CONTRACT_FILE}" ]] || die "file not found"
[[ "$(sed -n '1p' "${CONTRACT_FILE}")" == "# Project Contract" ]] || \
  die "must start with '# Project Contract'"

previous_line=0
for section in "${expected_sections[@]}"; do
  section_count="$(grep -Fxc "## ${section}" "${CONTRACT_FILE}" || true)"
  [[ "${section_count}" -eq 1 ]] || die "must contain one '## ${section}' section"
  section_line="$(grep -Fn "## ${section}" "${CONTRACT_FILE}" | cut -d: -f1)"
  [[ "${section_line}" -gt "${previous_line}" ]] || die "sections are out of order"
  previous_line="${section_line}"
done

section_count="$(grep -Ec '^## ' "${CONTRACT_FILE}" || true)"
[[ "${section_count}" -eq "${#expected_sections[@]}" ]] || \
  die "contains an unsupported or duplicate section"
grep -Fq '[TODO:' "${CONTRACT_FILE}" && die "contains an unfinished placeholder"

validate_section_fields "Verification" "Status|Bootstrap verification|Complete verification|Project checks"
if [[ "${CONTRACT_PROFILE}" == "repository" ]]; then
  validate_section_fields "Knowledge" "Repository instructions|Domain language|Architecture decisions"
  validate_section_fields "Work artifacts" "Specifications|Ticket backend"
  validate_section_fields "Workspace" "Default branch|Feature branch naming|Preserve unrelated working-tree changes"
  validate_section_fields "Delivery" "Mode|Remote and target branch|Require Delivery Gate"
else
  validate_section_fields "Knowledge" "Project instructions|Domain language|Architecture decisions"
  validate_section_fields "Work artifacts" "Specifications|Task tracking"
  validate_section_fields "Workspace" "Preserve unrelated workspace changes"
  validate_section_fields "Delivery" "Mode|Destination|Require Delivery Gate"
fi

verification_status="$(field_value "Verification" "Status")"
complete_verification="$(field_value "Verification" "Complete verification")"
case "${verification_status}" in
  bootstrap)
    [[ "${complete_verification}" == "unconfigured" ]] || \
      die "bootstrap status requires Complete verification: unconfigured"
    bootstrap_verification="$(field_value "Verification" "Bootstrap verification")"
    if [[ "${bootstrap_verification}" != "unconfigured" ]]; then
      validate_command "Bootstrap verification" "${bootstrap_verification}"
    fi
    ;;
  complete)
    validate_command "Complete verification" "${complete_verification}"
    if [[ "${complete_verification}" == "\`make verify\`" && -f "${PROJECT_CHECKS_FILE}" ]] && \
       grep -Eq '^PROJECT_CHECKS_CONFIGURED=0[[:space:]]*$' "${PROJECT_CHECKS_FILE}"; then
      die "Status is complete but make verify declares project checks unconfigured"
    fi
    ;;
  *) die "Status must be 'bootstrap' or 'complete'" ;;
esac

if [[ "${CONTRACT_PROFILE}" == "repository" ]]; then
  validate_relative_path "Knowledge" "Repository instructions"
else
  validate_relative_path "Knowledge" "Project instructions"
fi
validate_relative_path "Knowledge" "Domain language"
validate_relative_path "Knowledge" "Architecture decisions"
specifications="$(field_value "Work artifacts" "Specifications")"
validate_artifact_location "Specifications" "${specifications}"
validate_relative_path "Verification" "Project checks"

if [[ "${CONTRACT_PROFILE}" == "repository" ]]; then
  tracking_label="Ticket backend"
else
  tracking_label="Task tracking"
fi
tracking_value="$(field_value "Work artifacts" "${tracking_label}")"
if [[ "${tracking_value}" == "configured by \`"*"\`" ]]; then
  validate_configuration_reference "${tracking_label} configuration reference" "${tracking_value#configured by }"
else
  [[ "${tracking_value}" == "unconfigured" || "${tracking_value}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
    die "${tracking_label} must be 'unconfigured', a lowercase backend identifier, or 'configured by' one repository-relative path"
fi

if [[ "${CONTRACT_PROFILE}" == "repository" ]]; then
  [[ "$(field_value "Workspace" "Preserve unrelated working-tree changes")" == "yes" ]] || \
    die "Preserve unrelated working-tree changes must be 'yes'"

  default_branch="$(field_value "Workspace" "Default branch")"
  if [[ "${default_branch}" != "discover from the repository" ]]; then
    [[ "${default_branch}" =~ ^\`[^\`]+\`$ ]] || \
      die "Default branch must be discoverable or one backtick-wrapped safe branch name"
    branch_value="${default_branch#\`}"
    branch_value="${branch_value%\`}"
    is_valid_git_branch_name "${branch_value}" || \
      die "Default branch must be discoverable or one backtick-wrapped safe branch name"
  fi

  feature_branch_naming="$(field_value "Workspace" "Feature branch naming")"
  if [[ "${feature_branch_naming}" != "follow an explicit repository policy; otherwise propose a safe name" && \
        "${feature_branch_naming}" != "unconfigured" ]]; then
    [[ "${feature_branch_naming}" =~ ^\`[^\`]+\`$ ]] || \
      die "Feature branch naming must be the discovery policy, unconfigured, or one backtick-wrapped safe pattern"
    branch_value="${feature_branch_naming#\`}"
    branch_value="${branch_value%\`}"
    is_valid_feature_branch_pattern "${branch_value}" || \
      die "Feature branch naming must be the discovery policy, unconfigured, or one backtick-wrapped safe pattern"
  fi
else
  [[ "$(field_value "Workspace" "Preserve unrelated workspace changes")" == "yes" ]] || \
    die "Preserve unrelated workspace changes must be 'yes'"
fi

delivery_mode="$(field_value "Delivery" "Mode")"
if [[ "${CONTRACT_PROFILE}" == "folder" ]]; then
  case "${delivery_mode}" in
    none|unconfigured) ;;
    *) die "folder profile Mode must be none or unconfigured" ;;
  esac
else
  case "${delivery_mode}" in
    none|commit-only|push|pull-request|merge-request|unconfigured) ;;
    *) die "Mode must be none, commit-only, push, pull-request, merge-request, or unconfigured" ;;
  esac
fi
[[ "$(field_value "Delivery" "Require Delivery Gate")" == "yes" ]] || \
  die "Require Delivery Gate must be 'yes'"

if [[ "${CONTRACT_PROFILE}" == "repository" ]]; then
  remote_target="$(field_value "Delivery" "Remote and target branch")"
  if [[ "${remote_target}" != "discover and confirm before delivery" && "${remote_target}" != "unconfigured" ]]; then
    [[ "${remote_target}" =~ ^\`[^\`]+\`$ ]] || \
      die "Remote and target branch must be unconfigured, discoverable, or a backtick-wrapped remote/branch pair"
    remote_target_value="${remote_target#\`}"
    remote_target_value="${remote_target_value%\`}"
    remote_name="${remote_target_value%%/*}"
    branch_value="${remote_target_value#*/}"
    [[ "${remote_target_value}" == */* ]] && is_valid_remote_name "${remote_name}" && \
      is_valid_git_branch_name "${branch_value}" || \
      die "Remote and target branch must be unconfigured, discoverable, or a backtick-wrapped remote/branch pair"
  fi
else
  destination="$(field_value "Delivery" "Destination")"
  if [[ "${destination}" != "discover and confirm before delivery" && "${destination}" != "unconfigured" ]]; then
    validate_relative_path "Delivery" "Destination"
  fi
fi

echo "Validated Project Contract (${verification_status}): ${CONTRACT_FILE}"
