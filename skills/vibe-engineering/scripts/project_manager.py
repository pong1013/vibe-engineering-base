#!/usr/bin/env python3
"""Preview, apply, and inspect a project-scoped Vibe Engineering Harness."""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
from typing import Any


SKILL_ROOT = Path(__file__).resolve().parent.parent
SOURCE_VERSION = (SKILL_ROOT / "VERSION").read_text(encoding="utf-8").strip()
MANIFEST_PATH = Path(".agents/vibe-engineering/manifest.json")
BLOCK_START = "<!-- vibe-engineering:start -->"
BLOCK_END = "<!-- vibe-engineering:end -->"
LEARNED_START = "<!-- vibe-engineering:learned:start -->"
LEARNED_END = "<!-- vibe-engineering:learned:end -->"
MANAGED_BLOCK_TEMPLATE = """<!-- vibe-engineering:start -->
## Vibe Engineering Harness

- Read `.agents/project-contract.md` before changing this project.
- Keep reusable project workflows in `.agents/skills/`.
- Use `$harness-feedback` when concrete evidence justifies a durable Harness improvement.
<!-- vibe-engineering:learned:start -->
{learned}<!-- vibe-engineering:learned:end -->
<!-- vibe-engineering:end -->"""
DEFAULT_CAPABILITIES = ("harness", "harness-feedback")
KNOWN_CAPABILITIES = frozenset(DEFAULT_CAPABILITIES)
LEARN_CATEGORIES = frozenset(
    (
        "preference",
        "reversible-choice",
        "machine-checkable",
        "repository-guidance",
        "workflow-fact",
        "project-skill",
    )
)
SAFE_IDENTIFIER = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$")
CONTRACT_FACT_FIELDS = {
    "repository": {
        "Verification": {"Bootstrap verification", "Complete verification", "Project checks"},
        "Knowledge": {"Repository instructions", "Domain language", "Architecture decisions"},
        "Work artifacts": {"Specifications", "Ticket backend"},
        "Workspace": {"Default branch", "Feature branch naming"},
        "Delivery": {"Mode", "Remote and target branch"},
    },
    "folder": {
        "Verification": {"Bootstrap verification", "Complete verification", "Project checks"},
        "Knowledge": {"Project instructions", "Domain language", "Architecture decisions"},
        "Work artifacts": {"Specifications", "Task tracking"},
        "Delivery": {"Mode", "Destination"},
    },
}


class UserError(Exception):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def is_safe_git_branch_name(value: str) -> bool:
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", value):
        return False
    if value == "HEAD":
        return False
    if value.startswith(("/", "-")) or value.endswith("/") or ".." in value or "//" in value:
        return False
    return all(
        component
        and not component.startswith(".")
        and not component.endswith(".")
        and not component.endswith(".lock")
        for component in value.split("/")
    )


def is_safe_feature_branch_pattern(value: str) -> bool:
    return (
        re.fullmatch(r"[A-Za-z0-9._/*-]+", value) is not None
        and value.count("*") <= 1
        and is_safe_git_branch_name(value.replace("*", "x"))
    )


def is_safe_remote_name(value: str) -> bool:
    return bool(
        re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", value)
        and ".." not in value
        and not value.endswith((".", ".lock"))
    )


def is_safe_contract_command(value: str) -> bool:
    if not re.fullmatch(r"`[A-Za-z0-9./:+_-]+(?:[ \t][A-Za-z0-9./:=,@%+_-]+)*`", value):
        return False
    first = re.split(r"[ \t]", value[1:-1], maxsplit=1)[0]
    return first not in ("true", "false", ":", "yes", "no")


def contract_relative_path(value: str) -> Path | None:
    if not re.fullmatch(r"`[A-Za-z0-9._/-]+`", value):
        return None
    relative = Path(value[1:-1])
    if relative.is_absolute() or ".." in relative.parts:
        return None
    return relative


def validate_contract_candidate(target: Path, content: bytes, project_type: str) -> None:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        raise UserError("Project Contract candidate must be UTF-8 text") from None
    if not text.startswith("# Project Contract\n") and text != "# Project Contract":
        raise UserError("Project Contract candidate must start with '# Project Contract'")
    if "[TODO:" in text:
        raise UserError("Project Contract candidate contains an unfinished placeholder")

    expected_sections = ["Verification", "Knowledge", "Work artifacts", "Workspace", "Delivery"]
    headings = [line[3:] for line in text.splitlines() if line.startswith("## ")]
    if headings != expected_sections:
        raise UserError("Project Contract candidate has invalid sections")
    allowed = {
        "Verification": {"Status", "Bootstrap verification", "Complete verification", "Project checks"},
        "Knowledge": (
            {"Repository instructions", "Domain language", "Architecture decisions"}
            if project_type == "repository"
            else {"Project instructions", "Domain language", "Architecture decisions"}
        ),
        "Work artifacts": (
            {"Specifications", "Ticket backend"}
            if project_type == "repository"
            else {"Specifications", "Task tracking"}
        ),
        "Workspace": (
            {"Default branch", "Feature branch naming", "Preserve unrelated working-tree changes"}
            if project_type == "repository"
            else {"Preserve unrelated workspace changes"}
        ),
        "Delivery": (
            {"Mode", "Remote and target branch", "Require Delivery Gate"}
            if project_type == "repository"
            else {"Mode", "Destination", "Require Delivery Gate"}
        ),
    }
    fields: dict[tuple[str, str], str] = {}
    section = ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:]
            continue
        match = re.match(r"^- ([^:]+): (.*)$", line)
        if match is None:
            continue
        label, value = match.groups()
        if section not in allowed or label not in allowed[section]:
            raise UserError(f"Project Contract candidate contains unsupported field: {label}")
        key = (section, label)
        if key in fields:
            raise UserError(f"Project Contract candidate contains duplicate field: {label}")
        fields[key] = value

    def field(section_name: str, label: str) -> str:
        try:
            return fields[(section_name, label)]
        except KeyError:
            raise UserError(f"Project Contract candidate is missing {label}") from None

    status = field("Verification", "Status")
    complete = field("Verification", "Complete verification")
    if status == "bootstrap":
        if complete != "unconfigured":
            raise UserError("bootstrap Contract candidate requires complete verification unconfigured")
        bootstrap = field("Verification", "Bootstrap verification")
        if bootstrap != "unconfigured" and not is_safe_contract_command(bootstrap):
            raise UserError("Project Contract candidate has invalid bootstrap verification")
    elif status == "complete":
        if complete == "unconfigured" or not is_safe_contract_command(complete):
            raise UserError("complete Contract candidate requires an executable complete verification")
        project_checks_file = target / "scripts/harness/project-checks.sh"
        if complete == "`make verify`" and path_state(project_checks_file)["kind"] == "file":
            if re.search(
                r"^PROJECT_CHECKS_CONFIGURED=0[ \t]*$",
                project_checks_file.read_text(encoding="utf-8", errors="replace"),
                re.MULTILINE,
            ):
                raise UserError(
                    "complete Contract candidate conflicts with unconfigured project checks"
                )
    else:
        raise UserError("Project Contract candidate has invalid Status")

    path_fields = [
        ("Verification", "Project checks"),
        ("Knowledge", "Repository instructions" if project_type == "repository" else "Project instructions"),
        ("Knowledge", "Domain language"),
        ("Knowledge", "Architecture decisions"),
    ]
    for section_name, label in path_fields:
        value = field(section_name, label)
        if value != "unconfigured" and contract_relative_path(value) is None:
            raise UserError(f"Project Contract candidate has invalid {label}")

    def configured_reference(value: str, label: str) -> bool:
        match = re.fullmatch(r"configured by (`[A-Za-z0-9._/-]+`)", value)
        if match is None:
            return False
        relative = contract_relative_path(match.group(1))
        if relative is None:
            raise UserError(f"Project Contract candidate has unsafe {label} configuration reference")
        ensure_safe_write_path(target, relative)
        if path_state(target / relative)["kind"] != "file":
            raise UserError(f"Project Contract candidate has missing {label} configuration reference")
        return True

    specifications = field("Work artifacts", "Specifications")
    if specifications != "unconfigured" and not configured_reference(
        specifications, "Specifications"
    ) and contract_relative_path(specifications) is None:
        raise UserError("Project Contract candidate has invalid Specifications")
    tracker_label = "Ticket backend" if project_type == "repository" else "Task tracking"
    tracker = field("Work artifacts", tracker_label)
    if tracker != "unconfigured" and not configured_reference(tracker, tracker_label) and not SAFE_IDENTIFIER.fullmatch(tracker):
        raise UserError(f"Project Contract candidate has invalid {tracker_label}")

    if project_type == "repository":
        if field("Workspace", "Preserve unrelated working-tree changes") != "yes":
            raise UserError("Project Contract candidate must preserve unrelated working-tree changes")
        default_branch = field("Workspace", "Default branch")
        if default_branch != "discover from the repository" and not (
            default_branch.startswith("`")
            and default_branch.endswith("`")
            and is_safe_git_branch_name(default_branch[1:-1])
        ):
            raise UserError("Project Contract candidate has invalid Default branch")
        feature = field("Workspace", "Feature branch naming")
        if feature not in (
            "unconfigured",
            "follow an explicit repository policy; otherwise propose a safe name",
        ) and not (
            feature.startswith("`")
            and feature.endswith("`")
            and is_safe_feature_branch_pattern(feature[1:-1])
        ):
            raise UserError("Project Contract candidate has invalid Feature branch naming")
        modes = {"none", "commit-only", "push", "pull-request", "merge-request", "unconfigured"}
    else:
        if field("Workspace", "Preserve unrelated workspace changes") != "yes":
            raise UserError("Project Contract candidate must preserve unrelated workspace changes")
        modes = {"none", "unconfigured"}
    if field("Delivery", "Mode") not in modes:
        raise UserError("Project Contract candidate has invalid delivery Mode")
    if field("Delivery", "Require Delivery Gate") != "yes":
        raise UserError("Project Contract candidate must require Delivery Gate")
    if project_type == "repository":
        remote_target = field("Delivery", "Remote and target branch")
        if remote_target not in ("discover and confirm before delivery", "unconfigured"):
            pair = remote_target[1:-1] if remote_target.startswith("`") and remote_target.endswith("`") else ""
            remote, separator, branch = pair.partition("/")
            if not separator or not is_safe_remote_name(remote) or not is_safe_git_branch_name(branch):
                raise UserError("Project Contract candidate has invalid Remote and target branch")
    else:
        destination = field("Delivery", "Destination")
        if destination not in ("discover and confirm before delivery", "unconfigured") and contract_relative_path(destination) is None:
            raise UserError("Project Contract candidate has invalid Destination")


def reject_lexical_traversal(raw_target: str) -> None:
    if ".." in Path(raw_target).parts:
        raise UserError("target must not contain parent-directory traversal")


def validate_target(raw_target: str) -> Path:
    reject_lexical_traversal(raw_target)
    candidate = Path(raw_target).expanduser()
    if candidate.is_symlink():
        raise UserError("target must not be a symbolic link")
    try:
        target = candidate.resolve(strict=True)
    except (FileNotFoundError, RuntimeError):
        raise UserError("target must be an existing project folder") from None
    if not target.is_dir():
        raise UserError("target must be a directory")
    if target == Path(target.anchor):
        raise UserError("filesystem root cannot be used as a project target")
    if target == Path.home().resolve():
        raise UserError("the user home directory cannot be used as a project target")
    if not os.access(target, os.W_OK | os.X_OK):
        raise UserError("target must be writable")
    return target


def read_evidence(raw_path: str) -> tuple[dict[str, Any], str]:
    path = Path(raw_path).expanduser()
    state = path_state(path)
    if state["kind"] != "file":
        raise UserError("evidence file must be a regular file and not a symbolic link")
    content = path.read_bytes()
    if len(content) > 64 * 1024:
        raise UserError("evidence file is too large")
    try:
        evidence = json.loads(content.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise UserError("evidence file is not valid UTF-8 JSON") from None
    if (
        not isinstance(evidence, dict)
        or type(evidence.get("schema_version")) is not int
        or evidence["schema_version"] != 1
    ):
        raise UserError("evidence file has an unsupported schema")
    if evidence.get("category") not in LEARN_CATEGORIES:
        raise UserError("evidence category is invalid")
    pattern_id = evidence.get("pattern_id")
    if not isinstance(pattern_id, str) or not SAFE_IDENTIFIER.fullmatch(pattern_id):
        raise UserError("evidence pattern_id must be a safe lowercase identifier")
    if type(evidence.get("explicit_standard")) is not bool:
        raise UserError("evidence explicit_standard must be a boolean")
    occurrences = evidence.get("occurrences")
    if not isinstance(occurrences, list):
        raise UserError("evidence occurrences must be a list")
    occurrence_ids: list[str] = []
    for occurrence in occurrences:
        if not isinstance(occurrence, dict) or set(occurrence) != {"id"}:
            raise UserError("each evidence occurrence must contain only an id")
        occurrence_id = occurrence.get("id")
        if not isinstance(occurrence_id, str) or not SAFE_IDENTIFIER.fullmatch(occurrence_id):
            raise UserError("evidence occurrence id must be a safe lowercase identifier")
        occurrence_ids.append(occurrence_id)
    if len(occurrence_ids) != len(set(occurrence_ids)):
        raise UserError("evidence occurrence ids must be distinct")
    guidance = evidence.get("guidance")
    if not isinstance(guidance, list) or not guidance or not all(
        isinstance(item, str) and item.strip() for item in guidance
    ):
        raise UserError("evidence guidance must be a non-empty list of text")
    for value in [pattern_id, *occurrence_ids, *guidance]:
        validate_evidence_text(value)
    common_fields = {
        "schema_version", "category", "pattern_id", "occurrences", "explicit_standard", "guidance"
    }
    category = evidence["category"]
    extra_fields: set[str] = set()
    if category == "project-skill":
        extra_fields = {"skill_name", "trigger"}
    elif category == "machine-checkable":
        extra_fields = {"check_surface"}
    elif category == "workflow-fact":
        extra_fields = {"destination", "contract_section", "contract_field"}
    unknown = set(evidence) - common_fields - extra_fields
    if unknown:
        raise UserError(f"evidence contains unsupported fields: {', '.join(sorted(unknown))}")
    return evidence, digest(content)


def validate_evidence_text(value: str) -> None:
    if len(value) > 1000 or "\n" in value or "\r" in value or "\x00" in value:
        raise UserError("evidence text must be bounded single-line text")
    secret_patterns = (
        r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
        r"\bghp_[A-Za-z0-9]{20,}\b",
        r"\bgithub_pat_[A-Za-z0-9_]{20,}\b",
        r"\bAKIA[A-Z0-9]{16}\b",
        r"\bsk-[A-Za-z0-9]{20,}\b",
        r"\b(?:api[_-]?key|password|token)\s*[:=]\s*\S+",
    )
    if any(re.search(pattern, value, re.IGNORECASE) for pattern in secret_patterns):
        raise UserError("evidence appears to contain a secret; remove it before learning")
    if BLOCK_START in value or BLOCK_END in value or "<!-- vibe-engineering:" in value:
        raise UserError("evidence must not contain managed block markers")


def project_skill_content(evidence: dict[str, Any]) -> bytes:
    skill_name = evidence.get("skill_name")
    trigger = evidence.get("trigger")
    guidance = evidence["guidance"]
    if not isinstance(skill_name, str) or not SAFE_IDENTIFIER.fullmatch(skill_name):
        raise UserError("project Skill name must be a safe lowercase identifier")
    if not isinstance(trigger, str):
        raise UserError("project Skill trigger must be text")
    validate_evidence_text(trigger)
    if len(trigger) < 24 or len(trigger.split()) < 5:
        raise UserError("project Skill trigger is not distinct enough")
    if len(guidance) < 2 or any(len(item) < 24 for item in guidance):
        raise UserError("project Skill needs at least two reusable guidance items")
    if any(item.casefold() == trigger.casefold() for item in guidance):
        raise UserError("project Skill trigger and guidance must be distinct")
    title = " ".join(part.capitalize() for part in skill_name.split("-"))
    description = trigger.rstrip(".") + "."
    content = (
        "---\n"
        f"name: {skill_name}\n"
        f"description: {json.dumps(description)}\n"
        "---\n\n"
        f"# {title}\n\n"
        + "\n".join(f"- {item}" for item in guidance)
        + "\n"
    ).encode("utf-8")
    validate_generated_skill(content, skill_name)
    return content


def project_skill_metadata(skill_name: str) -> bytes:
    display_name = " ".join(part.capitalize() for part in skill_name.split("-"))
    return (
        "interface:\n"
        f"  display_name: {json.dumps(display_name)}\n"
        '  short_description: "Apply this reusable project workflow"\n'
        f"  default_prompt: {json.dumps('Use $' + skill_name + ' for this project task.')}\n"
    ).encode("utf-8")


def validate_generated_skill(content: bytes, expected_name: str) -> None:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        raise UserError("generated project Skill is not UTF-8") from None
    if not text.startswith("---\n") or "\n---\n" not in text[4:]:
        raise UserError("generated project Skill has invalid frontmatter")
    frontmatter = text.split("---\n", 2)[1]
    if f"name: {expected_name}\n" not in frontmatter or "description: " not in frontmatter:
        raise UserError("generated project Skill is missing required metadata")
    if "TODO" in text or "[TODO" in text:
        raise UserError("generated project Skill contains unfinished placeholders")


def build_project_skill_learn_plan(
    target: Path, evidence: dict[str, Any], evidence_digest: str
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    meets_threshold = len(evidence["occurrences"]) >= 2 or evidence["explicit_standard"] is True
    if not meets_threshold:
        return (
            {
                "command": "learn",
                "mode": "preview",
                "target": str(target),
                "decision": "insufficient-evidence",
                "reason": "project-skill-requires-two-distinct-occurrences-or-explicit-standard",
            },
            {},
        )
    content = project_skill_content(evidence)
    skill_name = evidence["skill_name"]
    skill_dir = Path(".agents/skills") / skill_name
    relative = skill_dir / "SKILL.md"
    metadata_relative = skill_dir / "agents/openai.yaml"
    metadata_content = project_skill_metadata(skill_name)
    ensure_safe_write_path(target, relative)
    ensure_safe_write_path(target, metadata_relative)
    directory_state = path_state(target / skill_dir)
    file_state = path_state(target / relative)
    metadata_state = path_state(target / metadata_relative)
    operation: dict[str, Any] = {
        "path": relative.as_posix(),
        "action": "create",
        "content": content.decode("utf-8"),
    }
    metadata_operation: dict[str, Any] = {
        "path": metadata_relative.as_posix(),
        "action": "create",
        "content": metadata_content.decode("utf-8"),
    }
    operations = [operation, metadata_operation]
    if (
        directory_state["kind"] != "missing"
        or file_state["kind"] != "missing"
        or metadata_state["kind"] != "missing"
    ):
        for item, item_relative, item_state, item_content in (
            (operation, relative, file_state, content),
            (metadata_operation, metadata_relative, metadata_state, metadata_content),
        ):
            item["action"] = "conflict"
            item["reason"] = "existing-project-skill"
            if item_state["kind"] == "file":
                item["diff"] = review_diff(
                    item_relative, (target / item_relative).read_bytes(), item_content
                )
        return (
            {
                "command": "learn",
                "mode": "preview",
                "target": str(target),
                "decision": "propose-project-skill",
                "operation": operation,
                "operations": operations,
            },
            {},
        )
    token_input = {
        "command": "learn",
        "target": str(target),
        "evidence_sha256": evidence_digest,
        "destination": relative.as_posix(),
        "observed_directory": directory_state,
        "observed_file": file_state,
        "observed_metadata": metadata_state,
        "desired_sha256": digest(content),
        "metadata_sha256": digest(metadata_content),
    }
    plan_token = digest(json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode())
    return (
        {
            "command": "learn",
            "mode": "preview",
            "target": str(target),
            "decision": "propose-project-skill",
            "operation": operation,
            "operations": operations,
            "plan_token": plan_token,
        },
        {relative: content, metadata_relative: metadata_content},
    )


def build_machine_check_learn_plan(
    target: Path, evidence: dict[str, Any], evidence_digest: str
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    surface = evidence.get("check_surface")
    if surface not in ("tests", "linters", "harness-checks"):
        raise UserError("machine-checkable evidence requires a known check_surface")
    pattern_id = evidence["pattern_id"]
    relative = Path(".agents/vibe-engineering/proposals/checks") / f"{pattern_id}.md"
    content = (
        f"# Check proposal: {pattern_id}\n\n"
        f"Target surface: `{surface}`\n\n"
        "## Required behavior\n\n"
        + "\n".join(f"- {item}" for item in evidence["guidance"])
        + "\n\n## Implementation boundary\n\n"
        "Review this proposal and implement it in the selected existing check surface. "
        "Keep executable logic out of this proposal.\n"
    ).encode("utf-8")
    ensure_safe_write_path(target, relative)
    observed = path_state(target / relative)
    operation: dict[str, Any] = {
        "path": relative.as_posix(),
        "action": "create",
        "content": content.decode("utf-8"),
    }
    if observed["kind"] != "missing":
        operation.update(action="conflict", reason="existing-check-proposal")
        if observed["kind"] == "file":
            operation["diff"] = review_diff(relative, (target / relative).read_bytes(), content)
        return (
            {
                "command": "learn",
                "mode": "preview",
                "target": str(target),
                "decision": "propose-machine-check",
                "operation": operation,
            },
            {},
        )
    token_input = {
        "command": "learn",
        "target": str(target),
        "evidence_sha256": evidence_digest,
        "destination": relative.as_posix(),
        "observed": observed,
        "desired_sha256": digest(content),
    }
    plan_token = digest(json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode())
    return (
        {
            "command": "learn",
            "mode": "preview",
            "target": str(target),
            "decision": "propose-machine-check",
            "operation": operation,
            "operations": [operation],
            "plan_token": plan_token,
        },
        {relative: content},
    )


def build_repository_guidance_learn_plan(
    target: Path, evidence: dict[str, Any], evidence_digest: str, manifest: dict[str, Any]
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    if "harness" not in manifest.get("capabilities", []):
        raise UserError("repository guidance requires the harness capability")
    relative = Path("AGENTS.md")
    ensure_safe_write_path(target, relative)
    state = path_state(target / relative)
    if state["kind"] != "file":
        raise UserError("managed AGENTS.md must be a regular file")
    current = (target / relative).read_bytes()
    entries = validated_manifest_entries(manifest)
    agents_entry = entries.get(relative)
    if agents_entry is None or agents_entry.get("scope") != "managed-block":
        raise UserError("manifest does not own the AGENTS.md managed block")
    if managed_block_checksum(current) != agents_entry["sha256"]:
        raise UserError("managed AGENTS.md guidance is locally modified; review it before learning")
    desired = update_agents(current)
    text = desired.decode("utf-8")
    additions = [f"- {item}" for item in evidence["guidance"]]
    learned_lines = {
        line
        for line in text.split(LEARNED_START, 1)[1].split(LEARNED_END, 1)[0].splitlines()
        if line
    }
    if all(addition in learned_lines for addition in additions):
        return (
            {
                "command": "learn",
                "mode": "preview",
                "target": str(target),
                "decision": "already-covered",
            },
            {},
        )
    learned = text.split(LEARNED_START, 1)[1].split(LEARNED_END, 1)[0].lstrip("\n")
    existing_lines = {line for line in learned.splitlines() if line}
    new_lines = [line for line in additions if line not in existing_lines]
    updated_learned = learned + "".join(f"{line}\n" for line in new_lines)
    desired = text.replace(
        LEARNED_START + "\n" + learned + LEARNED_END,
        LEARNED_START + "\n" + updated_learned + LEARNED_END,
        1,
    ).encode("utf-8")

    updated_manifest = json.loads(json.dumps(manifest))
    for entry in updated_manifest["managed"]:
        if entry.get("path") == relative.as_posix():
            entry["sha256"] = managed_block_checksum(desired)
            break
    manifest_content = json_bytes(updated_manifest)
    ensure_safe_write_path(target, MANIFEST_PATH)
    manifest_state = path_state(target / MANIFEST_PATH)
    operation = {
        "path": relative.as_posix(),
        "action": "update-managed-guidance",
        "diff": review_diff(relative, current, desired),
    }
    manifest_operation = {
        "path": MANIFEST_PATH.as_posix(),
        "action": "update-manifest",
        "diff": review_diff(
            MANIFEST_PATH, (target / MANIFEST_PATH).read_bytes(), manifest_content
        ),
    }
    token_input = {
        "command": "learn",
        "target": str(target),
        "evidence_sha256": evidence_digest,
        "destination": relative.as_posix(),
        "observed": state,
        "observed_manifest": manifest_state,
        "desired_sha256": digest(desired),
        "manifest_sha256": digest(manifest_content),
    }
    plan_token = digest(json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode())
    return (
        {
            "command": "learn",
            "mode": "preview",
            "target": str(target),
            "decision": "propose-repository-guidance",
            "operation": operation,
            "operations": [operation, manifest_operation],
            "plan_token": plan_token,
        },
        {relative: desired, MANIFEST_PATH: manifest_content},
    )


def contract_fact_value(
    target: Path, project_type: str, section: str, field: str, guidance: list[str], current: bytes
) -> bytes:
    if len(guidance) != 1:
        raise UserError("workflow-fact guidance must contain exactly one Contract value")
    value = guidance[0].strip()
    if (
        section not in CONTRACT_FACT_FIELDS[project_type]
        or field not in CONTRACT_FACT_FIELDS[project_type][section]
    ):
        raise UserError("workflow-fact Contract field is not supported for this project profile")

    relative_path_fields = {
        "Project checks",
        "Repository instructions",
        "Project instructions",
        "Domain language",
        "Architecture decisions",
        "Specifications",
        "Destination",
    }

    def configuration_reference_path(raw_value: str) -> Path | None:
        match = re.fullmatch(r"configured by `([A-Za-z0-9._/-]+)`", raw_value)
        if match is None:
            return None
        relative = Path(match.group(1))
        if relative.is_absolute() or ".." in relative.parts or relative == Path("."):
            raise UserError("workflow-fact configuration reference must remain inside the project")
        ensure_safe_write_path(target, relative)
        state = path_state(target / relative)
        if state["kind"] != "file":
            raise UserError(
                "workflow-fact configuration reference must name an existing regular file"
            )
        return relative

    if field in ("Bootstrap verification", "Complete verification"):
        if value != "unconfigured":
            if not re.fullmatch(
                r"`[A-Za-z0-9./:+_-]+(?:[ \t][A-Za-z0-9./:=,@%+_-]+)*`", value
            ):
                raise UserError("workflow-fact verification command is invalid")
            command = re.split(r"[ \t]", value[1:-1], maxsplit=1)[0]
            if command in ("true", "false", ":", "yes", "no"):
                raise UserError("workflow-fact verification command is not executable")
        if field == "Complete verification" and value != "unconfigured":
            text = current.decode("utf-8")
            if "- Status: bootstrap" in text:
                raise UserError("complete verification cannot be configured while Contract status is bootstrap")
    elif field in relative_path_fields:
        if value != "unconfigured":
            if field == "Destination" and value == "discover and confirm before delivery":
                pass
            elif field == "Specifications" and value.startswith("configured by "):
                if configuration_reference_path(value) is None:
                    raise UserError("workflow-fact Specifications configuration reference is invalid")
            elif not re.fullmatch(r"`[A-Za-z0-9._/-]+`", value):
                raise UserError("workflow-fact Contract path must be unconfigured or a safe relative path")
            else:
                raw_path = value[1:-1]
                candidate = Path(raw_path)
                if candidate.is_absolute() or ".." in candidate.parts:
                    raise UserError("workflow-fact Contract path must remain inside the project")
    elif field in ("Ticket backend", "Task tracking"):
        if value.startswith("configured by "):
            if configuration_reference_path(value) is None:
                raise UserError("workflow-fact tracker configuration reference is invalid")
        elif value != "unconfigured" and not SAFE_IDENTIFIER.fullmatch(value):
            raise UserError(
                "workflow-fact tracker must be unconfigured, a safe identifier, or a configuration reference"
            )
    elif field == "Default branch":
        if value != "discover from the repository" and not (
            value.startswith("`")
            and value.endswith("`")
            and is_safe_git_branch_name(value[1:-1])
        ):
            raise UserError("workflow-fact default branch is invalid")
    elif field == "Feature branch naming":
        if value not in (
            "unconfigured",
            "follow an explicit repository policy; otherwise propose a safe name",
        ) and not (
            value.startswith("`")
            and value.endswith("`")
            and is_safe_feature_branch_pattern(value[1:-1])
        ):
            raise UserError("workflow-fact feature branch naming is invalid")
    elif field == "Mode":
        allowed_modes = {"none", "unconfigured"} if project_type == "folder" else {
            "none", "commit-only", "push", "pull-request", "merge-request", "unconfigured"
        }
        if value not in allowed_modes:
            raise UserError("workflow-fact delivery mode is invalid for this project profile")
    elif field == "Remote and target branch":
        if value not in ("discover and confirm before delivery", "unconfigured"):
            pair = value[1:-1] if value.startswith("`") and value.endswith("`") else ""
            remote, separator, branch = pair.partition("/")
            if not separator or not is_safe_remote_name(remote) or not is_safe_git_branch_name(branch):
                raise UserError("workflow-fact remote and target branch is invalid")

    text = current.decode("utf-8")
    lines = text.splitlines(keepends=True)
    in_section = False
    matches: list[int] = []
    for index, line in enumerate(lines):
        stripped = line.rstrip("\r\n")
        if stripped == f"## {section}":
            in_section = True
            continue
        if stripped.startswith("## "):
            in_section = False
        if in_section and stripped.startswith(f"- {field}: "):
            matches.append(index)
    if len(matches) != 1:
        raise UserError("managed Project Contract does not contain the selected field exactly once")
    newline = (
        "\r\n"
        if lines[matches[0]].endswith("\r\n")
        else "\n"
        if lines[matches[0]].endswith("\n")
        else ""
    )
    lines[matches[0]] = f"- {field}: {value}{newline}"
    return "".join(lines).encode("utf-8")


def build_project_contract_learn_plan(
    target: Path, evidence: dict[str, Any], evidence_digest: str, manifest: dict[str, Any]
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    if evidence.get("destination") != "project-contract":
        raise UserError("workflow-fact destination must be project-contract")
    section = evidence.get("contract_section")
    field = evidence.get("contract_field")
    if not isinstance(section, str) or not isinstance(field, str):
        raise UserError("workflow-fact requires contract_section and contract_field")
    if "harness" not in manifest.get("capabilities", []):
        raise UserError("Project Contract learning requires the harness capability")
    relative = Path(".agents/project-contract.md")
    ensure_safe_write_path(target, relative)
    state = path_state(target / relative)
    if state["kind"] != "file":
        raise UserError("managed Project Contract must be a regular file")
    entries = validated_manifest_entries(manifest)
    entry = entries.get(relative)
    if entry is None or entry.get("scope") != "file":
        raise UserError("manifest does not own the Project Contract")
    current = (target / relative).read_bytes()
    if digest(current) != entry["sha256"]:
        raise UserError("managed Project Contract is locally modified; review it before learning")
    project_type = manifest["project_type"]
    desired = contract_fact_value(
        target, project_type, section, field, evidence["guidance"], current
    )
    validate_contract_candidate(target, desired, project_type)
    if desired == current:
        return (
            {
                "command": "learn",
                "mode": "preview",
                "target": str(target),
                "decision": "already-covered",
            },
            {},
        )
    updated_manifest = json.loads(json.dumps(manifest))
    for managed_entry in updated_manifest["managed"]:
        if managed_entry.get("path") == relative.as_posix():
            managed_entry["sha256"] = digest(desired)
            break
    manifest_content = json_bytes(updated_manifest)
    manifest_state = path_state(target / MANIFEST_PATH)
    operations = [
        {
            "path": relative.as_posix(),
            "action": "update-project-contract",
            "section": section,
            "field": field,
            "diff": review_diff(relative, current, desired),
        },
        {
            "path": MANIFEST_PATH.as_posix(),
            "action": "update-manifest",
            "diff": review_diff(
                MANIFEST_PATH, (target / MANIFEST_PATH).read_bytes(), manifest_content
            ),
        },
    ]
    token_input = {
        "command": "learn",
        "target": str(target),
        "evidence_sha256": evidence_digest,
        "destination": relative.as_posix(),
        "section": section,
        "field": field,
        "observed": state,
        "observed_manifest": manifest_state,
        "desired_sha256": digest(desired),
        "manifest_sha256": digest(manifest_content),
    }
    return (
        {
            "command": "learn",
            "mode": "preview",
            "target": str(target),
            "decision": "propose-project-contract",
            "operation": operations[0],
            "operations": operations,
            "plan_token": digest(
                json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode()
            ),
        },
        {relative: desired, MANIFEST_PATH: manifest_content},
    )


def learn(args: argparse.Namespace) -> dict[str, Any]:
    target = validate_target(args.target)
    evidence, evidence_digest = read_evidence(args.evidence_file)
    if evidence["category"] in ("preference", "reversible-choice"):
        if args.apply:
            raise UserError("this evidence is not eligible for durable learning")
        return {
            "command": "learn",
            "mode": "preview",
            "target": str(target),
            "decision": "no-durable-change",
            "reason": "one-off-or-reversible",
        }
    manifest = read_manifest(target)
    if manifest is None:
        raise UserError("Vibe Engineering is not installed; run setup first")
    validate_installed_manifest(target, manifest)
    if evidence["category"] == "project-skill":
        plan, writes = build_project_skill_learn_plan(target, evidence, evidence_digest)
    elif evidence["category"] == "machine-checkable":
        plan, writes = build_machine_check_learn_plan(target, evidence, evidence_digest)
    elif evidence["category"] == "repository-guidance":
        plan, writes = build_repository_guidance_learn_plan(
            target, evidence, evidence_digest, manifest
        )
    elif evidence["category"] == "workflow-fact":
        plan, writes = build_project_contract_learn_plan(
            target, evidence, evidence_digest, manifest
        )
    else:
        raise UserError("this evidence category is not implemented")
    if not args.apply:
        return plan
    if not args.plan_token:
        raise UserError("--plan-token is required with --apply")
    if not plan.get("plan_token") or args.plan_token != plan["plan_token"]:
        raise UserError("project or evidence state changed after preview; create a new learn preview")
    previewed_paths = {Path(item["path"]) for item in plan.get("operations", [])}
    if set(writes) != previewed_paths:
        raise UserError("learn plan does not describe every write")
    transactional_write(target, writes)
    plan["mode"] = "applied"
    return plan


def path_state(path: Path) -> dict[str, str]:
    try:
        mode = path.lstat().st_mode
    except FileNotFoundError:
        return {"kind": "missing"}
    if stat.S_ISLNK(mode):
        return {"kind": "symlink"}
    if stat.S_ISREG(mode):
        return {"kind": "file", "sha256": digest(path.read_bytes())}
    if stat.S_ISDIR(mode):
        return {"kind": "directory"}
    return {"kind": "unsupported"}


def ensure_safe_write_path(target: Path, relative: Path, *, allow_wrong_type: bool = False) -> None:
    current = target
    for part in relative.parts:
        current = current / part
        state = path_state(current)
        if state["kind"] == "symlink":
            raise UserError(f"managed write path must not use a symbolic link: {relative}")
        if current != target / relative and state["kind"] not in ("missing", "directory"):
            raise UserError(f"managed write path has a non-directory parent: {relative}")
    final_state = path_state(target / relative)
    if not allow_wrong_type and final_state["kind"] not in ("missing", "file"):
        raise UserError(f"managed write target must be a regular file: {relative}")


def detect_project_type(target: Path) -> str:
    marker = target / ".git"
    return "repository" if marker.is_dir() or marker.is_file() else "folder"


def normalize_capabilities(values: list[str] | None) -> tuple[str, ...]:
    selected = tuple(sorted(set(values or DEFAULT_CAPABILITIES)))
    unknown = set(selected) - KNOWN_CAPABILITIES
    if unknown:
        raise UserError(f"unknown capability: {', '.join(sorted(unknown))}")
    if not selected:
        raise UserError("select at least one capability")
    return selected


def update_agents(existing: bytes | None) -> bytes:
    try:
        text = existing.decode("utf-8") if existing is not None else "# Project instructions\n"
    except UnicodeDecodeError:
        raise UserError("AGENTS.md must be UTF-8 text") from None
    start_count = text.count(BLOCK_START)
    end_count = text.count(BLOCK_END)
    if start_count != end_count or start_count > 1:
        raise UserError("AGENTS.md contains an invalid Vibe Engineering managed block")
    learned = ""
    if start_count == 1:
        before, remainder = text.split(BLOCK_START, 1)
        current_block, after = remainder.split(BLOCK_END, 1)
        learned_start_count = current_block.count(LEARNED_START)
        learned_end_count = current_block.count(LEARNED_END)
        if learned_start_count != learned_end_count or learned_start_count > 1:
            raise UserError("AGENTS.md contains an invalid learned guidance block")
        if learned_start_count == 1:
            learned = current_block.split(LEARNED_START, 1)[1].split(LEARNED_END, 1)[0]
            learned = learned.lstrip("\n")
        result = before + render_managed_block(learned) + after
    else:
        separator = "" if text.endswith("\n\n") else ("\n" if text.endswith("\n") else "\n\n")
        result = text + separator + render_managed_block(learned) + "\n"
    return result.encode("utf-8")


def render_managed_block(learned: str) -> str:
    normalized = learned
    if normalized and not normalized.endswith("\n"):
        normalized += "\n"
    return MANAGED_BLOCK_TEMPLATE.format(learned=normalized)


def managed_block_checksum(content: bytes) -> str:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        return ""
    if text.count(BLOCK_START) != 1 or text.count(BLOCK_END) != 1:
        return ""
    block = BLOCK_START + text.split(BLOCK_START, 1)[1].split(BLOCK_END, 1)[0] + BLOCK_END
    return digest(block.encode("utf-8"))


def desired_files(
    target: Path, capabilities: tuple[str, ...], project_type: str
) -> tuple[dict[Path, bytes], list[dict[str, str]]]:
    desired: dict[Path, bytes] = {}
    entries: list[dict[str, str]] = []
    if "harness" in capabilities:
        agents_path = Path("AGENTS.md")
        current = target / agents_path
        existing = current.read_bytes() if path_state(current)["kind"] == "file" else None
        try:
            existing.decode("utf-8") if existing is not None else None
        except UnicodeDecodeError:
            desired[agents_path] = update_agents(None)
        else:
            desired[agents_path] = update_agents(existing)
        contract_path = Path(".agents/project-contract.md")
        contract_asset = "git.md" if project_type == "repository" else "folder.md"
        desired[contract_path] = (SKILL_ROOT / "assets/contracts" / contract_asset).read_bytes()
    if "harness-feedback" in capabilities:
        skill_path = Path(".agents/skills/harness-feedback/SKILL.md")
        desired[skill_path] = (SKILL_ROOT / "assets/harness-feedback/SKILL.md").read_bytes()
        metadata_path = Path(".agents/skills/harness-feedback/agents/openai.yaml")
        desired[metadata_path] = (
            SKILL_ROOT / "assets/harness-feedback/agents/openai.yaml"
        ).read_bytes()

    for relative, content in sorted(desired.items(), key=lambda item: str(item[0])):
        scope = "managed-block" if relative == Path("AGENTS.md") else "file"
        checksum = managed_block_checksum(content) if scope == "managed-block" else digest(content)
        entries.append({"path": relative.as_posix(), "sha256": checksum, "scope": scope})
    return desired, entries


def state_for_plan(target: Path, paths: list[Path]) -> dict[str, dict[str, str]]:
    observed = {}
    for relative in sorted(set(paths + [MANIFEST_PATH]), key=str):
        ensure_safe_write_path(target, relative, allow_wrong_type=True)
        observed[relative.as_posix()] = path_state(target / relative)
    return observed


def build_plan(
    target: Path, capabilities: tuple[str, ...], resolutions: tuple[str, ...]
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    project_type = detect_project_type(target)
    desired, entries = desired_files(target, capabilities, project_type)
    observed = state_for_plan(target, list(desired))
    if len(resolutions) != len(set(resolutions)):
        raise UserError("duplicate conflict resolution path")
    requested = tuple(sorted(resolutions))
    for raw in requested:
        candidate = Path(raw)
        if candidate.is_absolute() or ".." in candidate.parts or candidate == Path("."):
            raise UserError(f"unsafe conflict resolution path: {raw}")

    operations: list[dict[str, Any]] = []
    conflicts: set[str] = set()
    for relative, content in sorted(desired.items(), key=lambda item: str(item[0])):
        state = observed[relative.as_posix()]
        item: dict[str, Any] = {"path": relative.as_posix()}
        if state["kind"] == "missing":
            item["action"] = "create"
        elif state["kind"] != "file":
            item.update(action="conflict", reason=f"wrong-type:{state['kind']}")
            conflicts.add(relative.as_posix())
        elif state.get("sha256") == digest(content):
            item["action"] = "unchanged"
        else:
            current = (target / relative).read_bytes()
            try:
                current_text = current.decode("utf-8")
            except UnicodeDecodeError:
                current_text = None
            if (
                relative == Path("AGENTS.md")
                and current_text is not None
                and BLOCK_START not in current_text
            ):
                item.update(action="update", diff=review_diff(relative, current, content))
            else:
                reason = "existing-managed-block" if relative == Path("AGENTS.md") else "existing-project-file"
                item.update(
                    action="conflict",
                    reason=reason,
                    diff=review_diff(relative, current, content),
                )
                conflicts.add(relative.as_posix())
        operations.append(item)

    manifest = {
        "schema_version": 1,
        "source_version": SOURCE_VERSION,
        "project_type": project_type,
        "capabilities": list(capabilities),
        "managed": entries,
    }
    manifest_content = json_bytes(manifest)
    desired[MANIFEST_PATH] = manifest_content
    manifest_state = observed[MANIFEST_PATH.as_posix()]
    manifest_item: dict[str, Any] = {"path": MANIFEST_PATH.as_posix()}
    if manifest_state["kind"] == "missing":
        manifest_item["action"] = "create"
    elif manifest_state["kind"] != "file":
        manifest_item.update(action="conflict", reason=f"wrong-type:{manifest_state['kind']}")
        conflicts.add(MANIFEST_PATH.as_posix())
    elif manifest_state.get("sha256") == digest(manifest_content):
        manifest_item["action"] = "unchanged"
    else:
        manifest_item.update(
            action="conflict",
            reason="existing-manifest",
            diff=review_diff(
                MANIFEST_PATH, (target / MANIFEST_PATH).read_bytes(), manifest_content
            ),
        )
        conflicts.add(MANIFEST_PATH.as_posix())
    operations.append(manifest_item)

    unknown_resolutions = set(requested) - conflicts
    if unknown_resolutions:
        paths = ", ".join(sorted(unknown_resolutions))
        raise UserError(f"conflict resolution does not match a current conflict: {paths}")
    for item in operations:
        if item["path"] in requested:
            if item.get("reason", "").startswith("wrong-type:"):
                raise UserError(f"wrong-type conflict cannot be replaced safely: {item['path']}")
            item["resolution"] = "replace"

    token_input = {
        "target": str(target),
        "source_version": SOURCE_VERSION,
        "project_type": project_type,
        "capabilities": list(capabilities),
        "resolutions": list(requested),
        "observed": observed,
        "desired": {
            relative.as_posix(): digest(content)
            for relative, content in sorted(desired.items(), key=lambda item: str(item[0]))
        },
    }
    plan = {
        "command": "setup",
        "mode": "preview",
        "target": str(target),
        "project_type": manifest["project_type"],
        "source_version": SOURCE_VERSION,
        "capabilities": list(capabilities),
        "operations": operations,
    }
    manifest_unresolved = (
        manifest_item["action"] == "conflict" and manifest_item.get("resolution") != "replace"
    )
    if not manifest_unresolved:
        plan["plan_token"] = digest(
            json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode("utf-8")
        )
    return plan, desired


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_file() and not path.is_symlink():
        target_mode = stat.S_IMODE(path.stat().st_mode)
    else:
        current_umask = os.umask(0)
        os.umask(current_umask)
        target_mode = 0o666 & ~current_umask
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, target_mode)
        with os.fdopen(fd, "wb") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def setup(args: argparse.Namespace) -> dict[str, Any]:
    target = validate_target(args.target)
    capabilities = normalize_capabilities(args.capability)
    resolutions = tuple(args.resolve_conflict or ())
    plan, desired = build_plan(target, capabilities, resolutions)
    if not args.apply:
        return plan
    unresolved = [
        item["path"]
        for item in plan["operations"]
        if item["action"] == "conflict" and item.get("resolution") != "replace"
    ]
    if unresolved:
        raise UserError(f"setup has unresolved conflicts: {', '.join(unresolved)}")
    if not args.plan_token:
        raise UserError("--plan-token is required with --apply")
    if args.plan_token != plan.get("plan_token"):
        raise UserError("project state changed after preview; create a new setup preview")
    writes = {
        Path(item["path"]): desired[Path(item["path"])]
        for item in plan["operations"]
        if item["action"] in ("create", "update") or item.get("resolution") == "replace"
    }
    transactional_write(target, writes)
    plan["mode"] = "applied"
    return plan


def relative_sort_key(path: Path) -> tuple[int, str]:
    return (1 if path == MANIFEST_PATH else 0, path.as_posix())


def read_manifest(target: Path) -> dict[str, Any] | None:
    ensure_safe_write_path(target, MANIFEST_PATH)
    path = target / MANIFEST_PATH
    state = path_state(path)
    if state["kind"] == "missing":
        return None
    if state["kind"] != "file":
        raise UserError("manifest must be a regular file")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise UserError("manifest is not valid JSON") from None
    if not isinstance(value, dict) or not isinstance(value.get("managed"), list):
        raise UserError("manifest has an unsupported structure")
    return value


def validated_manifest_entries(manifest: dict[str, Any]) -> dict[Path, dict[str, str]]:
    entries: dict[Path, dict[str, str]] = {}
    for raw in manifest["managed"]:
        if not isinstance(raw, dict) or not isinstance(raw.get("path"), str):
            raise UserError("manifest contains an invalid managed path")
        unknown_fields = set(raw) - {"path", "sha256", "scope"}
        if unknown_fields:
            raise UserError(
                "manifest managed entry contains unsupported fields: "
                + ", ".join(sorted(unknown_fields))
            )
        relative = Path(raw["path"])
        if relative.is_absolute() or ".." in relative.parts or relative == Path("."):
            raise UserError("manifest contains an unsafe managed path")
        if relative in entries:
            raise UserError("manifest contains duplicate managed paths")
        if raw.get("scope") not in ("file", "managed-block"):
            raise UserError(f"manifest contains an invalid scope for {relative.as_posix()}")
        checksum = raw.get("sha256")
        if (
            not isinstance(checksum, str)
            or len(checksum) != 64
            or any(character not in "0123456789abcdef" for character in checksum)
        ):
            raise UserError(f"manifest contains an invalid checksum for {relative.as_posix()}")
        entries[relative] = raw
    return entries


def expected_manifest_scopes(capabilities: tuple[str, ...]) -> dict[Path, str]:
    expected: dict[Path, str] = {}
    if "harness" in capabilities:
        expected[Path("AGENTS.md")] = "managed-block"
        expected[Path(".agents/project-contract.md")] = "file"
    if "harness-feedback" in capabilities:
        expected[Path(".agents/skills/harness-feedback/SKILL.md")] = "file"
        expected[Path(".agents/skills/harness-feedback/agents/openai.yaml")] = "file"
    return expected


def validate_installed_manifest(
    target: Path, manifest: dict[str, Any]
) -> tuple[str, tuple[str, ...], str, dict[Path, dict[str, str]]]:
    unknown_fields = set(manifest) - {
        "schema_version", "source_version", "project_type", "capabilities", "managed"
    }
    if unknown_fields:
        raise UserError(
            "manifest contains unsupported fields: " + ", ".join(sorted(unknown_fields))
        )
    schema_version = manifest.get("schema_version")
    if type(schema_version) is not int or schema_version != 1:
        raise UserError("manifest has an unsupported schema version")
    installed_version = manifest.get("source_version")
    if (
        not isinstance(installed_version, str)
        or not installed_version.strip()
        or len(installed_version) > 128
    ):
        raise UserError("manifest has an invalid source version")
    capabilities_value = manifest.get("capabilities")
    if (
        not isinstance(capabilities_value, list)
        or not capabilities_value
        or not all(isinstance(value, str) for value in capabilities_value)
    ):
        raise UserError("manifest has invalid capabilities")
    if len(capabilities_value) != len(set(capabilities_value)):
        raise UserError("manifest contains duplicate capabilities")
    capabilities = normalize_capabilities(capabilities_value)
    project_type = detect_project_type(target)
    if manifest.get("project_type") != project_type:
        raise UserError("project type changed since setup; installed manifest is inconsistent")

    entries = validated_manifest_entries(manifest)
    expected = expected_manifest_scopes(capabilities)
    if set(entries) != set(expected):
        missing = sorted(path.as_posix() for path in set(expected) - set(entries))
        unexpected = sorted(path.as_posix() for path in set(entries) - set(expected))
        details = []
        if missing:
            details.append(f"missing {', '.join(missing)}")
        if unexpected:
            details.append(f"unexpected {', '.join(unexpected)}")
        raise UserError(f"manifest managed paths do not match capabilities: {'; '.join(details)}")
    for relative, scope in expected.items():
        if entries[relative]["scope"] != scope:
            raise UserError(f"manifest contains an invalid scope for {relative.as_posix()}")
    return installed_version, capabilities, project_type, entries


def checksum_for_scope(path: Path, scope: str) -> str:
    if scope == "managed-block":
        return managed_block_checksum(path.read_bytes())
    return digest(path.read_bytes())


def review_diff(relative: Path, current: bytes, desired: bytes) -> str:
    try:
        before = current.decode("utf-8").splitlines(keepends=True)
        after = desired.decode("utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        return (
            f"binary {relative.as_posix()}: current sha256={digest(current)} "
            f"desired sha256={digest(desired)}"
        )
    return "".join(
        difflib.unified_diff(
            before,
            after,
            fromfile=f"current/{relative.as_posix()}",
            tofile=f"packaged/{relative.as_posix()}",
        )
    )


def project_contract_values(content: bytes, project_type: str) -> dict[tuple[str, str], str]:
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        raise UserError("managed Project Contract must be UTF-8 text") from None
    values: dict[tuple[str, str], str] = {}
    section = ""
    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:]
            continue
        for field in CONTRACT_FACT_FIELDS[project_type].get(section, set()):
            prefix = f"- {field}: "
            if line.startswith(prefix):
                key = (section, field)
                if key in values:
                    raise UserError("managed Project Contract contains a duplicate workflow field")
                values[key] = line[len(prefix):]
    return values


def merge_project_contract_values(current: bytes, packaged: bytes, project_type: str) -> bytes:
    values = project_contract_values(current, project_type)
    try:
        text = packaged.decode("utf-8")
    except UnicodeDecodeError:
        raise UserError("packaged Project Contract must be UTF-8 text") from None
    lines = text.splitlines(keepends=True)
    section = ""
    for index, line in enumerate(lines):
        stripped = line.rstrip("\r\n")
        if stripped.startswith("## "):
            section = stripped[3:]
            continue
        for field in CONTRACT_FACT_FIELDS[project_type].get(section, set()):
            prefix = f"- {field}: "
            if stripped.startswith(prefix) and (section, field) in values:
                newline = (
                    "\r\n"
                    if line.endswith("\r\n")
                    else "\n"
                    if line.endswith("\n")
                    else ""
                )
                lines[index] = prefix + values[(section, field)] + newline
                break
    return "".join(lines).encode("utf-8")


def build_upgrade_plan(
    target: Path, resolutions: tuple[str, ...]
) -> tuple[dict[str, Any], dict[Path, bytes], dict[str, Any]]:
    manifest = read_manifest(target)
    if manifest is None:
        raise UserError("Vibe Engineering is not installed; run setup first")
    installed_version, capabilities, project_type, old_entries = validate_installed_manifest(
        target, manifest
    )
    desired, new_entries_list = desired_files(target, capabilities, project_type)
    contract_path = Path(".agents/project-contract.md")
    contract_state = path_state(target / contract_path)
    prior_contract = old_entries.get(contract_path)
    if (
        contract_path in desired
        and contract_state["kind"] == "file"
        and prior_contract is not None
        and prior_contract["scope"] == "file"
        and contract_state.get("sha256") == prior_contract["sha256"]
    ):
        desired[contract_path] = merge_project_contract_values(
            (target / contract_path).read_bytes(), desired[contract_path], project_type
        )
        for entry in new_entries_list:
            if entry["path"] == contract_path.as_posix():
                entry["sha256"] = digest(desired[contract_path])
                break
    if contract_path in desired:
        validate_contract_candidate(target, desired[contract_path], project_type)

    if len(resolutions) != len(set(resolutions)):
        raise UserError("duplicate conflict resolution path")
    requested = tuple(sorted(resolutions))
    for raw in requested:
        candidate = Path(raw)
        if candidate.is_absolute() or ".." in candidate.parts or candidate == Path("."):
            raise UserError(f"unsafe conflict resolution path: {raw}")

    observed: dict[str, dict[str, str]] = {}
    operations: list[dict[str, Any]] = []
    conflicts: set[str] = set()
    for relative, content in sorted(desired.items(), key=lambda item: str(item[0])):
        ensure_safe_write_path(target, relative, allow_wrong_type=True)
        state = path_state(target / relative)
        observed[relative.as_posix()] = state
        prior = old_entries.get(relative)
        item: dict[str, Any] = {"path": relative.as_posix()}
        if state["kind"] == "missing":
            item["action"] = "addition"
        elif state["kind"] != "file":
            item.update(action="conflict", reason=f"wrong-type:{state['kind']}")
            conflicts.add(relative.as_posix())
        elif prior is None:
            item.update(
                action="conflict",
                reason="untracked-existing-file",
                diff=review_diff(relative, (target / relative).read_bytes(), content),
            )
            conflicts.add(relative.as_posix())
        else:
            actual = checksum_for_scope(target / relative, prior["scope"])
            if actual != prior["sha256"]:
                item.update(
                    action="conflict",
                    reason="locally-modified",
                    diff=review_diff(relative, (target / relative).read_bytes(), content),
                )
                conflicts.add(relative.as_posix())
            elif digest((target / relative).read_bytes()) == digest(content):
                item["action"] = "unchanged"
            else:
                item["action"] = "replacement"
        operations.append(item)

    unknown_resolutions = set(requested) - conflicts
    if unknown_resolutions:
        paths = ", ".join(sorted(unknown_resolutions))
        raise UserError(f"conflict resolution does not match a current conflict: {paths}")
    for item in operations:
        if item["path"] in requested:
            if item.get("reason", "").startswith("wrong-type:"):
                raise UserError(f"wrong-type conflict cannot be replaced safely: {item['path']}")
            item["resolution"] = "replace"

    upgraded_manifest = {
        "schema_version": 1,
        "source_version": SOURCE_VERSION,
        "project_type": project_type,
        "capabilities": list(capabilities),
        "managed": new_entries_list,
    }
    ensure_safe_write_path(target, MANIFEST_PATH)
    manifest_state = path_state(target / MANIFEST_PATH)
    observed[MANIFEST_PATH.as_posix()] = manifest_state
    manifest_content = json_bytes(upgraded_manifest)
    desired[MANIFEST_PATH] = manifest_content
    manifest_operation: dict[str, Any] = {
        "path": MANIFEST_PATH.as_posix(),
        "action": (
            "unchanged"
            if manifest_state.get("sha256") == digest(manifest_content)
            else "replacement"
        ),
    }
    if manifest_operation["action"] == "replacement":
        manifest_operation["diff"] = review_diff(
            MANIFEST_PATH, (target / MANIFEST_PATH).read_bytes(), manifest_content
        )
    operations.append(manifest_operation)
    token_input = {
        "command": "upgrade",
        "target": str(target),
        "source_version": SOURCE_VERSION,
        "installed_version": installed_version,
        "capabilities": list(capabilities),
        "resolutions": list(requested),
        "observed": observed,
        "desired": {
            relative.as_posix(): digest(content)
            for relative, content in sorted(desired.items(), key=lambda item: str(item[0]))
        },
        "manifest": digest(manifest_content),
    }
    plan_token = digest(json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    plan = {
        "command": "upgrade",
        "mode": "preview",
        "target": str(target),
        "installed_version": installed_version,
        "source_version": SOURCE_VERSION,
        "capabilities": list(capabilities),
        "operations": operations,
        "plan_token": plan_token,
    }
    return plan, desired, upgraded_manifest


def transactional_write(target: Path, writes: dict[Path, bytes]) -> None:
    originals: dict[Path, tuple[bytes, int] | None] = {}
    created_directories: set[Path] = set()
    for relative in writes:
        ensure_safe_write_path(target, relative)
        path = target / relative
        state = path_state(path)
        originals[relative] = (path.read_bytes(), stat.S_IMODE(path.stat().st_mode)) if state["kind"] == "file" else None
        parent = path.parent
        while parent != target and not parent.exists():
            created_directories.add(parent)
            parent = parent.parent

    raw_fail_after = os.environ.get("VIBE_ENGINEERING_TEST_FAIL_AFTER_WRITES")
    fail_after: int | None = None
    if raw_fail_after is not None:
        try:
            fail_after = int(raw_fail_after)
        except ValueError:
            raise UserError("invalid test write-failure value") from None
        if fail_after < 0:
            raise UserError("invalid test write-failure value")

    written: list[Path] = []
    try:
        for relative, content in sorted(writes.items(), key=lambda item: relative_sort_key(item[0])):
            atomic_write(target / relative, content)
            written.append(relative)
            if fail_after is not None and len(written) >= fail_after:
                raise OSError("induced write failure")
    except (OSError, UserError) as error:
        rollback_errors = []
        for relative in reversed(written):
            path = target / relative
            original = originals[relative]
            try:
                if original is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic_write(path, original[0])
                    path.chmod(original[1])
            except OSError as rollback_error:
                rollback_errors.append(str(rollback_error))
        for directory in sorted(created_directories, key=lambda value: len(value.parts), reverse=True):
            try:
                directory.rmdir()
            except OSError:
                pass
        if rollback_errors:
            raise UserError("write failed and rollback could not restore every managed path") from error
        raise UserError(f"write failed; target restored: {error}") from None


def upgrade(args: argparse.Namespace) -> dict[str, Any]:
    target = validate_target(args.target)
    resolutions = tuple(args.resolve_conflict or ())
    plan, desired, upgraded_manifest = build_upgrade_plan(target, resolutions)
    if not args.apply:
        return plan
    if not args.plan_token:
        raise UserError("--plan-token is required with --apply")
    if args.plan_token != plan["plan_token"]:
        raise UserError("project state changed after preview; create a new upgrade preview")
    unresolved = [
        item["path"]
        for item in plan["operations"]
        if item["action"] == "conflict" and item.get("resolution") != "replace"
    ]
    if unresolved:
        raise UserError(f"upgrade has unresolved conflicts: {', '.join(unresolved)}")
    writes = {
        Path(item["path"]): desired[Path(item["path"])]
        for item in plan["operations"]
        if item["action"] in ("addition", "replacement") or item.get("resolution") == "replace"
    }
    transactional_write(target, writes)
    plan["mode"] = "applied"
    return plan


def status(args: argparse.Namespace) -> dict[str, Any]:
    target = validate_target(args.target)
    manifest = read_manifest(target)
    if manifest is None:
        return {"command": "status", "target": str(target), "status": "not-installed", "managed": []}
    installed_version, _, _, entries = validate_installed_manifest(target, manifest)
    results = []
    states = set()
    for relative, entry in entries.items():
        ensure_safe_write_path(target, relative, allow_wrong_type=True)
        file_state = path_state(target / relative)
        if file_state["kind"] == "missing":
            item_status = "missing"
        elif file_state["kind"] != "file":
            item_status = "modified"
        else:
            actual = (
                managed_block_checksum((target / relative).read_bytes())
                if entry.get("scope") == "managed-block"
                else file_state.get("sha256")
            )
            item_status = "current" if actual == entry.get("sha256") else "modified"
        states.add(item_status)
        results.append({"path": relative.as_posix(), "status": item_status})
    version_changed = installed_version != SOURCE_VERSION
    if version_changed:
        overall = "upgrade-available"
    elif "modified" in states:
        overall = "modified"
    elif "missing" in states:
        overall = "missing"
    else:
        overall = "current"
    return {
        "command": "status",
        "target": str(target),
        "status": overall,
        "source_version": SOURCE_VERSION,
        "installed_version": installed_version,
        "managed": results,
    }


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    setup_parser = commands.add_parser("setup", help="preview or apply project Harness setup")
    setup_parser.add_argument("--target", required=True)
    setup_parser.add_argument("--capability", action="append", choices=sorted(KNOWN_CAPABILITIES))
    setup_parser.add_argument("--resolve-conflict", action="append")
    setup_parser.add_argument("--apply", action="store_true")
    setup_parser.add_argument("--plan-token")
    setup_parser.set_defaults(handler=setup)
    status_parser = commands.add_parser("status", help="inspect installed managed files without writing")
    status_parser.add_argument("--target", required=True)
    status_parser.set_defaults(handler=status)
    upgrade_parser = commands.add_parser("upgrade", help="preview or apply a manifest-based upgrade")
    upgrade_parser.add_argument("--target", required=True)
    upgrade_parser.add_argument("--resolve-conflict", action="append")
    upgrade_parser.add_argument("--apply", action="store_true")
    upgrade_parser.add_argument("--plan-token")
    upgrade_parser.set_defaults(handler=upgrade)
    learn_parser = commands.add_parser("learn", help="preview or apply evidence-based project learning")
    learn_parser.add_argument("--target", required=True)
    learn_parser.add_argument("--evidence-file", required=True)
    learn_parser.add_argument("--apply", action="store_true")
    learn_parser.add_argument("--plan-token")
    learn_parser.set_defaults(handler=learn)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        result = args.handler(args)
    except UserError as error:
        print(json.dumps({"error": str(error)}, sort_keys=True), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
