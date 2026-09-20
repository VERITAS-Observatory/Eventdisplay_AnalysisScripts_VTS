#!/usr/bin/env python3
"""Safely merge mutable DBTEXT refresh files into complete tar packages.

Only runinfo, laserrun, rundqm, and target from a db_bulk_export.py refresh
directory are compared.  An existing package is replaced atomically only when
at least one of those payloads differs byte-for-byte.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import os
import shutil
import stat
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

MUTABLE_FILES = ("runinfo", "laserrun", "rundqm", "target")


class PackageNotFoundError(RuntimeError):
    """Raised when a refresh entry has no existing DBTEXT tar package."""


class PackageUnreadableError(RuntimeError):
    """Raised when an existing DBTEXT tar package is not a readable gzip tar."""


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_subdirectory(run_id: int) -> str:
    return str(run_id)[:1] if run_id < 100000 else str(run_id)[:2]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def archive_member_sha256(archive: tarfile.TarFile, name: str) -> str | None:
    try:
        member = archive.getmember(name)
    except KeyError:
        return None
    if not member.isfile():
        return None
    source = archive.extractfile(member)
    if source is None:
        return None
    digest = hashlib.sha256()
    with source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def archive_member_text(archive_path: Path, member_name: str) -> list[str]:
    """Read an ASCII payload from a package for user-facing unified diffs."""
    try:
        with tarfile.open(archive_path, "r:gz") as archive:
            try:
                member = archive.getmember(member_name)
            except KeyError:
                return []
            source = archive.extractfile(member)
            if source is None:
                return []
            with source:
                return source.read().decode("utf-8", errors="replace").splitlines(keepends=True)
    except (tarfile.TarError, EOFError, OSError) as error:
        raise PackageUnreadableError(
            f"cannot read original package {archive_path}: {error}"
        ) from error


def print_payload_diff(archive_path: Path, run_id: int, refresh_dir: Path, name: str) -> None:
    member_name = f"{run_id}/{run_id}.{name}"
    old_lines = archive_member_text(archive_path, member_name)
    new_path = refresh_dir / f"{run_id}.{name}"
    new_lines = new_path.read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    for line in difflib.unified_diff(
        old_lines,
        new_lines,
        fromfile=f"{archive_path}:{member_name}",
        tofile=str(new_path),
    ):
        print(line, end="")


def refresh_entries(refresh_root: Path) -> list[tuple[int, Path, tuple[str, ...]]]:
    """Return valid primary and laser-only refresh directories."""
    entries: list[tuple[int, Path, tuple[str, ...]]] = []
    for manifest in sorted(refresh_root.rglob("*.metadata.json")):
        run_dir = manifest.parent
        try:
            metadata = json.loads(manifest.read_text(encoding="utf-8"))
            run_id = int(metadata["run_id"])
        except (json.JSONDecodeError, KeyError, ValueError) as error:
            raise RuntimeError(f"invalid refresh manifest: {manifest}: {error}") from error
        if run_dir.name != str(run_id) or metadata.get("export_scope") != "mutable-fields-only":
            raise RuntimeError(f"not a mutable-fields refresh directory: {run_dir}")
        available = tuple(
            name for name in MUTABLE_FILES if (run_dir / f"{run_id}.{name}").is_file()
        )
        if available == ("rundqm",):
            entries.append((run_id, run_dir, available))  # laser-only dependency
        elif available == MUTABLE_FILES:
            entries.append((run_id, run_dir, available))  # requested observation
        else:
            raise RuntimeError(
                f"incomplete refresh payload in {run_dir}: found "
                f"{', '.join(available) or 'no mutable files'}"
            )
    if not entries:
        raise RuntimeError(f"no mutable-fields refresh manifests found below {refresh_root}")
    return entries


def changed_payloads(
    archive_path: Path, run_id: int, refresh_dir: Path, names: tuple[str, ...]
) -> list[str]:
    if not archive_path.is_file():
        raise PackageNotFoundError(f"original package not found: {archive_path}")
    try:
        with tarfile.open(archive_path, "r:gz") as archive:
            changed = []
            for name in names:
                refresh_file = refresh_dir / f"{run_id}.{name}"
                archived_hash = archive_member_sha256(archive, f"{run_id}/{run_id}.{name}")
                if archived_hash != sha256_file(refresh_file):
                    changed.append(name)
            return changed
    except (tarfile.TarError, EOFError, OSError) as error:
        raise PackageUnreadableError(
            f"cannot read original package {archive_path}: {error}"
        ) from error


def safe_extract(archive: tarfile.TarFile, destination: Path) -> None:
    for member in archive.getmembers():
        member_path = PurePosixPath(member.name)
        if member_path.is_absolute() or ".." in member_path.parts:
            raise RuntimeError(f"unsafe member in archive: {member.name}")
        if member.issym() or member.islnk() or member.isdev():
            raise RuntimeError(f"unsupported link or device in archive: {member.name}")
    archive.extractall(destination, filter="data")


def write_metadata(run_dir: Path, run_id: int, refresh_dir: Path, changed: list[str]) -> None:
    metadata_path = run_dir / f"{run_id}.metadata.json"
    files = []
    for path in sorted(run_dir.rglob("*")):
        if not path.is_file() or path == metadata_path:
            continue
        stat_result = path.stat()
        files.append(
            {
                "path": path.relative_to(run_dir).as_posix(),
                "size": stat_result.st_size,
                "mtime_utc": datetime.fromtimestamp(stat_result.st_mtime, timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "sha256": sha256_file(path),
            }
        )
    refresh_metadata = json.loads(
        (refresh_dir / f"{run_id}.metadata.json").read_text(encoding="utf-8")
    )
    metadata = {
        "metadata_version": 1,
        "run_id": run_id,
        "archive_filename": f"{run_id}.tar.gz",
        "metadata_created_utc": utc_now(),
        "extraction": refresh_metadata.get("extraction", {}),
        "package_update": {
            "updated_utc": utc_now(),
            "producer": "db_update_mutable_tar_packages.py",
            "refresh_directory": str(refresh_dir),
            "changed_payload_files": changed,
        },
        "database_schemas": ["VERITAS", "VOFFLINE"],
        "checksum_algorithm": "SHA-256",
        "checksum_scope": "all payload files below; this metadata file is excluded",
        "files": files,
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def sync_file(path: Path) -> None:
    with path.open("rb") as handle:
        os.fsync(handle.fileno())


def sync_directory(path: Path) -> None:
    directory_fd = os.open(path, os.O_RDONLY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)


def verify_archive(archive_path: Path, run_id: int, refresh_dir: Path, changed: list[str]) -> None:
    with tarfile.open(archive_path, "r:gz") as archive:
        for name in changed:
            if archive_member_sha256(archive, f"{run_id}/{run_id}.{name}") != sha256_file(
                refresh_dir / f"{run_id}.{name}"
            ):
                raise RuntimeError(f"verification failed for {archive_path}: {name}")
        if archive_member_sha256(archive, f"{run_id}/{run_id}.metadata.json") is None:
            raise RuntimeError(f"metadata missing from {archive_path}")


def replace_archive(archive_path: Path, run_id: int, refresh_dir: Path, changed: list[str]) -> None:
    parent = archive_path.parent
    staging = Path(tempfile.mkdtemp(prefix=f".{run_id}.dbtext-update-", dir=parent))
    temporary_archive: Path | None = None
    backup_archive: Path | None = None
    replaced = False
    try:
        with tarfile.open(archive_path, "r:gz") as archive:
            safe_extract(archive, staging)
        run_dir = staging / str(run_id)
        if not run_dir.is_dir():
            raise RuntimeError(f"package {archive_path} does not contain {run_id}/")
        for name in changed:
            shutil.copyfile(refresh_dir / f"{run_id}.{name}", run_dir / f"{run_id}.{name}")
        write_metadata(run_dir, run_id, refresh_dir, changed)
        with tempfile.NamedTemporaryFile(
            prefix=f".{run_id}.", suffix=".tar.gz", dir=parent, delete=False
        ) as handle:
            temporary_archive = Path(handle.name)
        with tarfile.open(temporary_archive, "w:gz") as archive:
            archive.add(run_dir, arcname=str(run_id))
        sync_file(temporary_archive)
        verify_archive(temporary_archive, run_id, refresh_dir, changed)
        os.chmod(temporary_archive, stat.S_IMODE(archive_path.stat().st_mode))
        backup_archive = parent / f".{run_id}.dbtext-original.{os.getpid()}.tar.gz"
        os.link(archive_path, backup_archive)
        os.replace(temporary_archive, archive_path)
        temporary_archive = None
        replaced = True
        sync_file(archive_path)
        sync_directory(parent)
        verify_archive(archive_path, run_id, refresh_dir, changed)
        backup_archive.unlink()
        backup_archive = None
    except Exception:
        if replaced and backup_archive is not None and backup_archive.exists():
            archive_path.unlink(missing_ok=True)
            os.replace(backup_archive, archive_path)
            sync_file(archive_path)
            sync_directory(parent)
            backup_archive = None
        raise
    finally:
        if temporary_archive is not None:
            temporary_archive.unlink(missing_ok=True)
        if backup_archive is not None:
            backup_archive.unlink(missing_ok=True)
        shutil.rmtree(staging, ignore_errors=True)


def laser_dependencies(refresh_dir: Path, run_id: int) -> set[int]:
    laser_file = refresh_dir / f"{run_id}.laserrun"
    dependencies: set[int] = set()
    for line_number, line in enumerate(laser_file.read_text(encoding="utf-8").splitlines()[1:], 2):
        if not line:
            continue
        try:
            dependencies.add(int(line.split("|", 1)[0]))
        except ValueError as error:
            raise RuntimeError(f"invalid laser run ID in {laser_file}:{line_number}") from error
    return dependencies


def write_run_list(path: Path, run_ids: set[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text("".join(f"{run_id}\n" for run_id in sorted(run_ids)), encoding="utf-8")
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update complete DBTEXT packages from a mutable-fields refresh."
    )
    parser.add_argument(
        "refresh_dir", type=Path, help="output directory from query_run_list_bulk.sh"
    )
    parser.add_argument(
        "dbtext_dir", type=Path, help="root directory containing existing DBTEXT tar packages"
    )
    parser.add_argument(
        "--changed-runs",
        type=Path,
        required=True,
        help="reprocessing-trigger run list (one requested run ID per line)",
    )
    parser.add_argument(
        "--changed-packages",
        type=Path,
        help="all tar package IDs changed; defaults beside --changed-runs",
    )
    parser.add_argument(
        "--not-found-runs",
        type=Path,
        help="refresh IDs with no original tar package; defaults beside --changed-runs",
    )
    parser.add_argument(
        "--unreadable-runs",
        type=Path,
        help="existing but unreadable package IDs; defaults beside --changed-runs",
    )
    parser.add_argument(
        "--min-run-id",
        type=int,
        help="only inspect refresh entries with run ID greater than or equal to this value",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="replace changed tar packages; otherwise only perform a dry run",
    )
    args = parser.parse_args()

    refresh_root = args.refresh_dir.resolve()
    dbtext_root = args.dbtext_dir.resolve()
    if not refresh_root.is_dir() or not dbtext_root.is_dir():
        parser.error("refresh_dir and dbtext_dir must both be existing directories")
    package_list = args.changed_packages or args.changed_runs.with_name(
        args.changed_runs.stem + ".packages" + args.changed_runs.suffix
    )
    not_found_list = args.not_found_runs or args.changed_runs.with_name(
        args.changed_runs.stem + ".not-found" + args.changed_runs.suffix
    )
    unreadable_list = args.unreadable_runs or args.changed_runs.with_name(
        args.changed_runs.stem + ".unreadable" + args.changed_runs.suffix
    )
    changed_file_lists = {
        name: args.changed_runs.with_name(
            args.changed_runs.stem + f".{name}" + args.changed_runs.suffix
        )
        for name in MUTABLE_FILES
    }
    entries = refresh_entries(refresh_root)
    if args.min_run_id is not None:
        entries = [entry for entry in entries if entry[0] >= args.min_run_id]
        if not entries:
            parser.error(f"no refresh entries have run ID >= {args.min_run_id}")
    requested = {
        run_id: directory for run_id, directory, names in entries if names == MUTABLE_FILES
    }
    changed_packages: set[int] = set()
    changed_requested: set[int] = set()
    changed_by_file = {name: set() for name in MUTABLE_FILES}
    not_found_runs: set[int] = set()
    unreadable_runs: set[int] = set()
    failures = []
    for run_id, refresh_dir, names in entries:
        archive_path = dbtext_root / run_subdirectory(run_id) / f"{run_id}.tar.gz"
        try:
            changed = changed_payloads(archive_path, run_id, refresh_dir, names)
            if not changed:
                continue
            if args.apply:
                replace_archive(archive_path, run_id, refresh_dir, changed)
            changed_packages.add(run_id)
            for name in changed:
                changed_by_file[name].add(run_id)
            if names == MUTABLE_FILES:
                changed_requested.add(run_id)
            print(f"{'UPDATED' if args.apply else 'WOULD UPDATE'} {run_id}: {', '.join(changed)}")
            if not args.apply:
                for name in changed:
                    print_payload_diff(archive_path, run_id, refresh_dir, name)
        except PackageNotFoundError as error:
            not_found_runs.add(run_id)
            failures.append(str(error))
            print(f"NOT FOUND {run_id}: {error}", file=sys.stderr)
        except PackageUnreadableError as error:
            # Treat an unreadable existing package as missing from the point
            # of view of recovery: it cannot be safely updated in place.
            not_found_runs.add(run_id)
            unreadable_runs.add(run_id)
            failures.append(str(error))
            print(f"UNREADABLE {run_id}: {error}", file=sys.stderr)
        except RuntimeError as error:
            failures.append(str(error))
            print(f"ERROR {run_id}: {error}", file=sys.stderr)

    changed_laser_dependencies = changed_packages - set(requested)
    for run_id, refresh_dir in requested.items():
        if laser_dependencies(refresh_dir, run_id) & changed_laser_dependencies:
            changed_requested.add(run_id)
    write_run_list(args.changed_runs, changed_requested)
    write_run_list(package_list, changed_packages)
    write_run_list(not_found_list, not_found_runs)
    write_run_list(unreadable_list, unreadable_runs)
    for name, path in changed_file_lists.items():
        write_run_list(path, changed_by_file[name])
    print(
        f"{'Updated' if args.apply else 'Would update'} {len(changed_packages)} packages; "
        f"{len(changed_requested)} requested runs written to {args.changed_runs}; "
        f"all package IDs written to {package_list}; "
        f"{len(not_found_runs)} missing-package run IDs written to {not_found_list}; "
        f"{len(unreadable_runs)} unreadable-package run IDs written to {unreadable_list}; "
        + "; ".join(
            f"{len(changed_by_file[name])} {name} changes written to {changed_file_lists[name]}"
            for name in MUTABLE_FILES
        ),
        file=sys.stderr,
    )
    if failures:
        print(
            "No reprocessing should be started until the errors above are "
            "resolved and this command exits successfully.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
