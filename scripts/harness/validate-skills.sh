#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILLS_DIR="${HARNESS_SKILLS_DIR:-${ROOT_DIR}/.agents/skills}"
skill_count=0

if [[ ! -d "${SKILLS_DIR}" ]]; then
  echo "Skill directory not found: ${SKILLS_DIR}" >&2
  exit 1
fi

for skill_dir in "${SKILLS_DIR}"/*; do
  [[ -d "${skill_dir}" ]] || continue
  skill_count=$((skill_count + 1))

  skill_file="${skill_dir}/SKILL.md"
  metadata_file="${skill_dir}/agents/openai.yaml"
  expected_name="$(basename "${skill_dir}")"

  if [[ ! -f "${skill_file}" ]]; then
    echo "Missing SKILL.md: ${skill_dir}" >&2
    exit 1
  fi
  if [[ "$(sed -n '1p' "${skill_file}")" != "---" ]]; then
    echo "Missing opening frontmatter delimiter: ${skill_file}" >&2
    exit 1
  fi

  frontmatter_end="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "${skill_file}")"
  if [[ -z "${frontmatter_end}" ]]; then
    echo "Missing closing frontmatter delimiter: ${skill_file}" >&2
    exit 1
  fi

  skill_name="$(awk -v end="${frontmatter_end}" 'NR > 1 && NR < end && /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); print; exit }' "${skill_file}")"
  description="$(awk -v end="${frontmatter_end}" 'NR > 1 && NR < end && /^description:[[:space:]]*/ { sub(/^description:[[:space:]]*/, ""); print; exit }' "${skill_file}")"
  extra_keys="$(awk -v end="${frontmatter_end}" '
    NR > 1 && NR < end && /^[a-zA-Z0-9_-]+:/ {
      key=$0
      sub(/:.*/, "", key)
      if (key != "name" && key != "description") print key
    }
  ' "${skill_file}")"

  if [[ "${skill_name}" != "${expected_name}" ]]; then
    echo "Skill name '${skill_name}' must match directory '${expected_name}': ${skill_file}" >&2
    exit 1
  fi
  if [[ ! "${skill_name}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || [[ ${#skill_name} -gt 64 ]]; then
    echo "Invalid skill name '${skill_name}': ${skill_file}" >&2
    exit 1
  fi
  if [[ -z "${description}" ]] || [[ "${description}" == *"[TODO:"* ]]; then
    echo "Skill description is missing or unfinished: ${skill_file}" >&2
    exit 1
  fi
  if [[ -n "${extra_keys}" ]]; then
    echo "Unsupported SKILL.md frontmatter key(s) in ${skill_file}: ${extra_keys}" >&2
    exit 1
  fi
  if grep -Fq '[TODO:' "${skill_file}"; then
    echo "Unfinished scaffold placeholder: ${skill_file}" >&2
    exit 1
  fi

  if [[ ! -f "${metadata_file}" ]]; then
    echo "Missing agents/openai.yaml: ${skill_dir}" >&2
    exit 1
  fi
  if ! grep -Eq '^interface:[[:space:]]*$' "${metadata_file}" || \
     ! grep -Eq '^  display_name: ".+"[[:space:]]*$' "${metadata_file}" || \
     ! grep -Eq '^  short_description: ".+"[[:space:]]*$' "${metadata_file}" || \
     ! grep -Eq '^  default_prompt: ".+"[[:space:]]*$' "${metadata_file}"; then
    echo "Invalid agents/openai.yaml interface metadata: ${metadata_file}" >&2
    exit 1
  fi

  short_description="$(sed -n 's/^  short_description: "\(.*\)"[[:space:]]*$/\1/p' "${metadata_file}")"
  default_prompt="$(sed -n 's/^  default_prompt: "\(.*\)"[[:space:]]*$/\1/p' "${metadata_file}")"
  if [[ ${#short_description} -lt 25 || ${#short_description} -gt 64 ]]; then
    echo "short_description must be 25-64 characters: ${metadata_file}" >&2
    exit 1
  fi
  if [[ "${default_prompt}" != *"\$${skill_name}"* ]]; then
    echo "default_prompt must mention \$${skill_name}: ${metadata_file}" >&2
    exit 1
  fi

  policy_count="$(grep -Ec '^policy:[[:space:]]*$' "${metadata_file}" || true)"
  invocation_key_count="$(grep -Ec '^[[:space:]]*allow_implicit_invocation:' "${metadata_file}" || true)"
  invocation_policy="$(awk '
    /^policy:[[:space:]]*$/ { in_policy=1; next }
    /^[^[:space:]][^:]*:/ { in_policy=0 }
    in_policy && /^  allow_implicit_invocation:[[:space:]]*/ {
      sub(/^  allow_implicit_invocation:[[:space:]]*/, "")
      sub(/[[:space:]]*$/, "")
      print
      exit
    }
  ' "${metadata_file}")"

  if [[ "${policy_count}" -gt 1 ]] || [[ "${invocation_key_count}" -gt 1 ]]; then
    echo "Duplicate invocation policy metadata: ${metadata_file}" >&2
    exit 1
  fi
  if [[ "${policy_count}" -eq 0 ]] && [[ "${invocation_key_count}" -ne 0 ]]; then
    echo "allow_implicit_invocation must be under policy: ${metadata_file}" >&2
    exit 1
  fi
  if [[ "${policy_count}" -eq 1 ]] && \
     { [[ "${invocation_key_count}" -ne 1 ]] || \
       { [[ "${invocation_policy}" != "true" ]] && [[ "${invocation_policy}" != "false" ]]; }; }; then
    echo "policy.allow_implicit_invocation must be true or false: ${metadata_file}" >&2
    exit 1
  fi
done

if [[ ${skill_count} -eq 0 ]]; then
  echo "No active skills found under ${SKILLS_DIR}" >&2
  exit 1
fi

echo "Validated ${skill_count} active repository skill(s)."
