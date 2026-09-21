#!/usr/bin/env python3
"""Preview, apply, and inspect a project-scoped Vibe Engineering Harness."""

from __future__ import annotations

import argparse
import difflib
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


def validated_manifest_entries(manifest: dict[str, Any]) -> dict[Path, dict[str, str]]:
    entries: dict[Path, dict[str, str]] = {}
    for raw in manifest["managed"]:
        if not isinstance(raw, dict) or not isinstance(raw.get("path"), str):
            raise UserError("manifest contains an invalid managed path")
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


def build_upgrade_plan(
    target: Path, resolutions: tuple[str, ...]
) -> tuple[dict[str, Any], dict[Path, bytes], dict[str, Any]]:
    manifest = read_manifest(target)
    if manifest is None:
        raise UserError("Vibe Engineering is not installed; run setup first")
    if manifest.get("schema_version") != 1:
        raise UserError("manifest has an unsupported schema version")
    installed_version = manifest.get("source_version")
    if not isinstance(installed_version, str) or not installed_version:
        raise UserError("manifest has an invalid source version")
    capabilities_value = manifest.get("capabilities")
    if not isinstance(capabilities_value, list) or not all(
        isinstance(value, str) for value in capabilities_value
    ):
        raise UserError("manifest has invalid capabilities")
    capabilities = normalize_capabilities(capabilities_value)
    project_type = detect_project_type(target)
    if manifest.get("project_type") != project_type:
        raise UserError("project type changed since setup; upgrade cannot continue")

    old_entries = validated_manifest_entries(manifest)
    desired, new_entries_list = desired_files(target, capabilities, project_type)
    new_entries = {Path(entry["path"]): entry for entry in new_entries_list}
    missing_from_source = set(old_entries) - set(new_entries)
    if missing_from_source:
        paths = ", ".join(path.as_posix() for path in sorted(missing_from_source, key=str))
        raise UserError(f"source no longer defines managed paths: {paths}")

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
    observed[MANIFEST_PATH.as_posix()] = path_state(target / MANIFEST_PATH)
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
        "manifest": digest(json_bytes(upgraded_manifest)),
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
            raise UserError("upgrade failed and rollback could not restore every managed path") from error
        raise UserError(f"upgrade write failed; target restored: {error}") from None


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
    manifest_content = json_bytes(upgraded_manifest)
    if (target / MANIFEST_PATH).read_bytes() != manifest_content:
        writes[MANIFEST_PATH] = manifest_content
    transactional_write(target, writes)
    plan["mode"] = "applied"
    return plan


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
    upgrade_parser = commands.add_parser("upgrade", help="preview or apply a manifest-based upgrade")
    upgrade_parser.add_argument("--target", required=True)
    upgrade_parser.add_argument("--resolve-conflict", action="append")
    upgrade_parser.add_argument("--apply", action="store_true")
    upgrade_parser.add_argument("--plan-token")
    upgrade_parser.set_defaults(handler=upgrade)
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
