#!/usr/bin/env python3
"""Low-load bulk refresh of DBTEXT fields that can change after a run.

Only these files are written:
  * <run>.runinfo
  * <run>.laserrun
  * <run>.rundqm
  * <run>.target

No high-rate telemetry, hardware configuration, pointing, weather, or flasher
calibration data is queried. This makes the database workload proportional to
the number of run-ID batches, not observation duration.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shlex
import shutil
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Iterator

RUNINFO_HEADER = (
    "run_id|run_type|observing_mode|run_status|db_start_time|db_end_time|"
    "data_start_time|data_end_time|duration|weather|config_mask|pointing_mode|"
    "trigger_config|trigger_multiplicity|trigger_coincidence|offsetRA|offsetDEC|"
    "offset_distance|offset_angle|source_id"
)
DQM_HEADER = (
    "run_id|data_category|status|status_reason|tel_cut_mask|usable_duration|"
    "time_cut_mask|light_level|vpm_config_mask|authors|comment"
)
HEADERS = {
    "runinfo": RUNINFO_HEADER,
    "laserrun": "run_id|excluded_telescopes|config_mask",
    "rundqm": DQM_HEADER,
    "target": "source_id|ra|decl|epoch|description",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def run_subdirectory(run_id: int) -> str:
    run_text = str(run_id)
    return run_text[:1] if run_id < 100000 else run_text[:2]


def batches(values: Iterable[int], size: int) -> Iterator[list[int]]:
    batch: list[int] = []
    for value in values:
        batch.append(value)
        if len(batch) == size:
            yield batch
            batch = []
    if batch:
        yield batch


def parse_run_list(path: Path) -> list[int]:
    run_ids: list[int] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            run_ids.append(int(line.split()[0]))
        except ValueError as error:
            raise ValueError(f"invalid run ID at {path}:{line_number}: {line}") from error
    return sorted(set(run_ids))


def mysql_rows(command: list[str], schema: str, query: str) -> Iterator[list[str]]:
    """Run one small, read-only batch query and return mysql tabular output."""
    result = subprocess.run(
        command
        + ["--batch", "--skip-column-names", "--unbuffered", "-e", f"USE `{schema}`; {query}"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        stderr = result.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(stderr or f"MySQL query against {schema} failed")
    # MySQL batch output escapes embedded LF characters but can emit a raw
    # carriage return from a text column. Do not use splitlines(): it would
    # mistake that CR (seen in tblRun_Analysis_Comments.comment) for the start
    # of a new row. This matches db_rundqm.sh, which removes CR characters.
    stdout = result.stdout.decode("utf-8", errors="replace")
    for line in stdout.split("\n"):
        if line:
            yield [field.replace("\r", "") for field in line.split("\t")]


def query_in(
    command: list[str], schema: str, prefix: str, run_ids: Iterable[int], batch_size: int
) -> Iterator[list[str]]:
    for batch in batches(sorted(set(run_ids)), batch_size):
        yield from mysql_rows(command, schema, prefix + " (" + ",".join(map(str, batch)) + ")")


class OutputRun:
    def __init__(self, root: Path, run_id: int):
        self.run_id = run_id
        self.directory = root / run_subdirectory(run_id) / str(run_id)
        self.directory.mkdir(parents=True, exist_ok=True)

    def path(self, name: str) -> Path:
        return self.directory / f"{self.run_id}.{name}"

    def write_header(self, name: str) -> None:
        self.path(name).write_text(HEADERS[name] + "\n", encoding="utf-8")

    def append(self, name: str, row: Iterable[str]) -> None:
        with self.path(name).open("a", encoding="utf-8") as handle:
            handle.write("|".join(row) + "\n")


def write_metadata(
    directory: Path, run_id: int, started: str, finished: str, db_time: str | None
) -> None:
    metadata_path = directory / f"{run_id}.metadata.json"
    files = []
    for path in sorted(directory.iterdir()):
        if not path.is_file() or path == metadata_path:
            continue
        stat = path.stat()
        files.append(
            {
                "path": path.name,
                "size": stat.st_size,
                "mtime_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).strftime(
                    "%Y-%m-%dT%H:%M:%SZ"
                ),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
    metadata = {
        "metadata_version": 1,
        "run_id": run_id,
        "archive_filename": f"{run_id}.tar.gz",
        "metadata_created_utc": finished,
        "extraction": {
            "started_utc": started,
            "finished_utc": finished,
            "database_server_time_utc_start": db_time,
            "database_server_time_utc_end": db_time,
            "producer": "db_bulk_export.py (mutable-fields refresh)",
        },
        "database_schemas": ["VERITAS", "VOFFLINE"],
        "export_scope": "mutable-fields-only",
        "payload_files": [path["path"].split(".", 1)[1] for path in files],
        "checksum_algorithm": "SHA-256",
        "checksum_scope": "all payload files below; this metadata file is excluded",
        "files": files,
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def prepare_output(root: Path, run_id: int, overwrite: bool) -> OutputRun:
    directory = root / run_subdirectory(run_id) / str(run_id)
    if directory.exists() and any(directory.iterdir()):
        if not overwrite:
            raise RuntimeError(
                f"output already exists: {directory}; use a new --output-dir or --overwrite"
            )
        shutil.rmtree(directory)
    return OutputRun(root, run_id)


def main() -> int:
    parser = argparse.ArgumentParser(description="Bulk refresh mutable DBTEXT fields only.")
    parser.add_argument(
        "run_list", type=Path, help="one run ID per line; additional columns are ignored"
    )
    parser.add_argument(
        "--output-dir", type=Path, required=True, help="new DBTEXT refresh-output root"
    )
    parser.add_argument(
        "--run-id-batch-size",
        type=int,
        default=500,
        help="maximum run IDs per query (default: 500)",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="replace existing run directories below --output-dir",
    )
    # Accepted only so previous command lines remain usable; they have no
    # effect because this exporter does not query any time-series tables.
    parser.add_argument("--chunk-hours", help=argparse.SUPPRESS)
    parser.add_argument("--l1-chunk-minutes", help=argparse.SUPPRESS)
    parser.add_argument(
        "--db-command-script", type=Path, default=Path(__file__).with_name("db_mysqldb.sh")
    )
    args = parser.parse_args()
    if args.run_id_batch_size <= 0:
        parser.error("--run-id-batch-size must be positive")

    requested = parse_run_list(args.run_list)
    if not requested:
        parser.error("run list is empty")
    root = args.output_dir.resolve()
    root.mkdir(parents=True, exist_ok=True)
    command = shlex.split(subprocess.check_output([str(args.db_command_script)], text=True).strip())
    if not command or command[0] != "mysql":
        raise RuntimeError(f"unexpected DB command from {args.db_command_script}")

    started = utc_now()
    timestamp = next(
        mysql_rows(command, "VERITAS", "SELECT DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%dT%H:%i:%SZ')"),
        [],
    )
    db_time = timestamp[0] if timestamp else None
    outputs = {run_id: prepare_output(root, run_id, args.overwrite) for run_id in requested}
    for output in outputs.values():
        for name in HEADERS:
            output.write_header(name)

    run_info: dict[int, list[str]] = {}
    runinfo_query = (
        "SELECT run_id,run_type,observing_mode,run_status,db_start_time,db_end_time,"
        "data_start_time,data_end_time,duration,weather,config_mask,pointing_mode,"
        "trigger_config,trigger_multiplicity,trigger_coincidence,offsetRA,offsetDEC,"
        "offset_distance,offset_angle,source_id FROM tblRun_Info WHERE run_id IN"
    )
    for row in query_in(command, "VERITAS", runinfo_query, requested, args.run_id_batch_size):
        run_id = int(row[0])
        run_info[run_id] = row
        outputs[run_id].append("runinfo", row)
    print(f"Fetched run information for {len(run_info)} requested runs", file=sys.stderr)

    laser_rows: dict[int, list[list[str]]] = defaultdict(list)
    laser_query = (
        "SELECT requested.run_id,info.run_id,grp_cmt.excluded_telescopes,info.config_mask "
        "FROM tblRun_Group AS requested "
        "JOIN tblRun_GroupComment AS grp_cmt ON grp_cmt.group_id=requested.group_id "
        "JOIN tblRun_Group AS grp ON grp.group_id=grp_cmt.group_id "
        "JOIN tblRun_Info AS info ON grp.run_id=info.run_id "
        "WHERE grp_cmt.group_type='laser' AND (info.run_type='flasher' OR info.run_type='laser') "
        "AND requested.run_id IN"
    )
    # Use every requested ID, rather than only IDs with a tblRun_Info record.
    # This is deliberately the same selection rule as db_laserrun.sh.
    for row in query_in(command, "VERITAS", laser_query, requested, args.run_id_batch_size):
        observation_id, laser_id, excluded, config = row
        laser_rows[int(observation_id)].append([laser_id, excluded, config])
        outputs[int(observation_id)].append("laserrun", [laser_id, excluded, config])

    laser_ids = {int(row[0]) for rows in laser_rows.values() for row in rows}
    for run_id in sorted(laser_ids - set(outputs)):
        outputs[run_id] = prepare_output(root, run_id, args.overwrite)
        outputs[run_id].write_header("rundqm")

    dqm_query = (
        "SELECT run_id,data_category,status,status_reason,tel_cut_mask,"
        "usable_duration,time_cut_mask,"
        "light_level,vpm_config_mask,authors,comment FROM tblRun_Analysis_Comments WHERE run_id IN"
    )
    for row in query_in(
        command, "VOFFLINE", dqm_query, set(requested) | laser_ids, args.run_id_batch_size
    ):
        run_id = int(row[0])
        if run_id in outputs:
            outputs[run_id].append("rundqm", row)

    source_rows = {
        row[0]: row
        for row in mysql_rows(
            command,
            "VERITAS",
            "SELECT source_id,ra,decl,epoch,description FROM tblObserving_Sources",
        )
    }
    for run_id, row in run_info.items():
        source = row[19]
        if source in source_rows:
            outputs[run_id].append("target", source_rows[source])

    finished = utc_now()
    for output in outputs.values():
        write_metadata(output.directory, output.run_id, started, finished, db_time)
    print(
        f"Refreshed runinfo, laserrun, rundqm, and target for {len(requested)} requested runs "
        f"and {len(outputs) - len(requested)} laser dependencies in {root}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
