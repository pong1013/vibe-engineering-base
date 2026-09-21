#!/usr/bin/env python3
"""Preview, apply, and inspect a project-scoped Vibe Engineering Harness."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from typing import Any


SKILL_ROOT = Path(__file__).resolve().parent.parent
SOURCE_VERSION = (SKILL_ROOT / "VERSION").read_text(encoding="utf-8").strip()
MANIFEST_PATH = Path(".agents/vibe-engineering/manifest.json")
BLOCK_START = "<!-- vibe-engineering:start -->"
BLOCK_END = "<!-- vibe-engineering:end -->"
MANAGED_BLOCK = """<!-- vibe-engineering:start -->
## Vibe Engineering Harness

- Read `.agents/project-contract.md` before changing this project.
- Keep reusable project workflows in `.agents/skills/`.
- Use `$harness-feedback` when concrete evidence justifies a durable Harness improvement.
<!-- vibe-engineering:end -->"""
DEFAULT_CAPABILITIES = ("harness", "harness-feedback")
KNOWN_CAPABILITIES = frozenset(DEFAULT_CAPABILITIES)


class UserError(Exception):
    pass


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


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


def ensure_safe_write_path(target: Path, relative: Path) -> None:
    current = target
    for part in relative.parts:
        current = current / part
        state = path_state(current)
        if state["kind"] == "symlink":
            raise UserError(f"managed write path must not use a symbolic link: {relative}")
        if current != target / relative and state["kind"] not in ("missing", "directory"):
            raise UserError(f"managed write path has a non-directory parent: {relative}")
    final_state = path_state(target / relative)
    if final_state["kind"] not in ("missing", "file"):
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
    if start_count == 1:
        before, remainder = text.split(BLOCK_START, 1)
        _, after = remainder.split(BLOCK_END, 1)
        result = before + MANAGED_BLOCK + after
    else:
        separator = "" if text.endswith("\n\n") else ("\n" if text.endswith("\n") else "\n\n")
        result = text + separator + MANAGED_BLOCK + "\n"
    return result.encode("utf-8")


def managed_block_checksum(content: bytes) -> str:
    text = content.decode("utf-8")
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
        ensure_safe_write_path(target, relative)
        observed[relative.as_posix()] = path_state(target / relative)
    return observed


def build_plan(target: Path, capabilities: tuple[str, ...]) -> tuple[dict[str, Any], dict[Path, bytes]]:
    project_type = detect_project_type(target)
    desired, entries = desired_files(target, capabilities, project_type)
    observed = state_for_plan(target, list(desired))
    operations = []
    for relative, content in sorted(desired.items(), key=lambda item: str(item[0])):
        state = observed[relative.as_posix()]
        if state.get("sha256") == digest(content):
            action = "unchanged"
        elif state["kind"] == "missing":
            action = "create"
        else:
            action = "update"
        operations.append({"action": action, "path": relative.as_posix()})
    manifest = {
        "schema_version": 1,
        "source_version": SOURCE_VERSION,
        "project_type": project_type,
        "capabilities": list(capabilities),
        "managed": entries,
    }
    token_input = {
        "target": str(target),
        "source_version": SOURCE_VERSION,
        "project_type": project_type,
        "capabilities": list(capabilities),
        "observed": observed,
        "desired": {
            relative.as_posix(): digest(content)
            for relative, content in sorted(desired.items(), key=lambda item: str(item[0]))
        },
    }
    plan_token = digest(json.dumps(token_input, sort_keys=True, separators=(",", ":")).encode("utf-8"))
    plan = {
        "command": "setup",
        "mode": "preview",
        "target": str(target),
        "project_type": manifest["project_type"],
        "source_version": SOURCE_VERSION,
        "capabilities": list(capabilities),
        "operations": operations,
        "plan_token": plan_token,
    }
    desired[MANIFEST_PATH] = json_bytes(manifest)
    return plan, desired


def atomic_write(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
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
    plan, desired = build_plan(target, capabilities)
    if not args.apply:
        return plan
    if not args.plan_token:
        raise UserError("--plan-token is required with --apply")
    if args.plan_token != plan["plan_token"]:
        raise UserError("project state changed after preview; create a new setup preview")
    for relative, content in sorted(desired.items(), key=lambda item: relative_sort_key(item[0])):
        ensure_safe_write_path(target, relative)
        atomic_write(target / relative, content)
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


def status(args: argparse.Namespace) -> dict[str, Any]:
    target = validate_target(args.target)
    manifest = read_manifest(target)
    if manifest is None:
        return {"command": "status", "target": str(target), "status": "not-installed", "managed": []}
    results = []
    states = set()
    for entry in manifest["managed"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise UserError("manifest contains an invalid managed path")
        relative = Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise UserError("manifest contains an unsafe managed path")
        ensure_safe_write_path(target, relative)
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
    version_changed = manifest.get("source_version") != SOURCE_VERSION
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
        "installed_version": manifest.get("source_version"),
        "managed": results,
    }


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    commands = root.add_subparsers(dest="command", required=True)
    setup_parser = commands.add_parser("setup", help="preview or apply project Harness setup")
    setup_parser.add_argument("--target", required=True)
    setup_parser.add_argument("--capability", action="append", choices=sorted(KNOWN_CAPABILITIES))
    setup_parser.add_argument("--apply", action="store_true")
    setup_parser.add_argument("--plan-token")
    setup_parser.set_defaults(handler=setup)
    status_parser = commands.add_parser("status", help="inspect installed managed files without writing")
    status_parser.add_argument("--target", required=True)
    status_parser.set_defaults(handler=status)
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
