#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT_FILE="${HARNESS_PROJECT_CONTRACT:-${ROOT_DIR}/.agents/project-contract.md}"
CONTRACT_ROOT="${HARNESS_CONTRACT_ROOT:-${ROOT_DIR}}"
PROJECT_CHECKS_FILE="${HARNESS_PROJECT_CHECKS:-${CONTRACT_ROOT}/scripts/harness/project-checks.sh}"
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

validate_command() {
  local label="$1"
  local value="$2"
  local first_token
  [[ "${value}" =~ ^\`[^\`]+\`$ ]] || die "${label} must be one backtick-wrapped command"
  value="${value#\`}"
  value="${value%\`}"
  first_token="${value%% *}"
  case "${first_token}" in
    true|false|:|yes|no) die "${label} is not an executable verification entrypoint" ;;
  esac
  [[ "${value}" =~ ^[A-Za-z0-9./:+_-]+([[:space:]][A-Za-z0-9./:=,@%+_-]+)*$ ]] || \
    die "${label} must be a direct command without shell control operators"
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
validate_section_fields "Knowledge" "Repository instructions|Domain language|Architecture decisions"
validate_section_fields "Work artifacts" "Specifications|Ticket backend"
validate_section_fields "Workspace" "Default branch|Feature branch naming|Preserve unrelated working-tree changes"
validate_section_fields "Delivery" "Mode|Remote and target branch|Require Delivery Gate"

verification_status="$(field_value "Verification" "Status")"
complete_verification="$(field_value "Verification" "Complete verification")"
case "${verification_status}" in
  bootstrap)
    [[ "${complete_verification}" == "unconfigured" ]] || \
      die "bootstrap status requires Complete verification: unconfigured"
    bootstrap_verification="$(field_value "Verification" "Bootstrap verification")"
    validate_command "Bootstrap verification" "${bootstrap_verification}"
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

validate_relative_path "Knowledge" "Repository instructions"
validate_relative_path "Knowledge" "Domain language"
validate_relative_path "Knowledge" "Architecture decisions"
validate_relative_path "Work artifacts" "Specifications"
validate_relative_path "Verification" "Project checks"

ticket_backend="$(field_value "Work artifacts" "Ticket backend")"
[[ "${ticket_backend}" == "unconfigured" || "${ticket_backend}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || \
  die "Ticket backend must be 'unconfigured' or a lowercase backend identifier"

[[ "$(field_value "Workspace" "Preserve unrelated working-tree changes")" == "yes" ]] || \
  die "Preserve unrelated working-tree changes must be 'yes'"

default_branch="$(field_value "Workspace" "Default branch")"
if [[ "${default_branch}" != "discover from the repository" ]]; then
  [[ "${default_branch}" =~ ^\`[A-Za-z0-9._/-]+\`$ && "${default_branch}" != *..* ]] || \
    die "Default branch must be discoverable or one backtick-wrapped safe branch name"
fi

delivery_mode="$(field_value "Delivery" "Mode")"
case "${delivery_mode}" in
  none|commit-only|push|pull-request|merge-request|unconfigured) ;;
  *) die "Mode must be none, commit-only, push, pull-request, merge-request, or unconfigured" ;;
esac
[[ "$(field_value "Delivery" "Require Delivery Gate")" == "yes" ]] || \
  die "Require Delivery Gate must be 'yes'"

remote_target="$(field_value "Delivery" "Remote and target branch")"
if [[ "${remote_target}" != "discover and confirm before delivery" && "${remote_target}" != "unconfigured" ]]; then
  [[ "${remote_target}" =~ ^\`[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+\`$ && "${remote_target}" != *..* ]] || \
    die "Remote and target branch must be unconfigured, discoverable, or a backtick-wrapped remote/branch pair"
fi

echo "Validated Project Contract (${verification_status}): ${CONTRACT_FILE}"
