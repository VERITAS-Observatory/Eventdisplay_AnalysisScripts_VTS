#!/bin/bash
# Print DBTEXT information for runs whose V2DL3 processing found an empty event list.

if [[ -z ${VERITAS_DATA_DIR:-} ]]; then
    echo "VERITAS_DATA_DIR environmental variable not defined" >&2
    exit 1
fi

while IFS= read -r -d '' log_file; do
    run_id=$(basename "$log_file" .log)
    if [[ ! $run_id =~ ^[0-9]+$ ]]; then
        echo "Skipping log with invalid run ID: $log_file" >&2
        continue
    fi

    if (( run_id < 100000 )); then
        db_subdir=${run_id:0:1}
    else
        db_subdir=${run_id:0:2}
    fi
    db_tar="${VERITAS_DATA_DIR%/}/shared/DBTEXT/${db_subdir}/${run_id}.tar.gz"

    echo "===== Run ${run_id} (${log_file}) ====="
    if [[ ! -f $db_tar ]]; then
        echo "DBTEXT tar package not found: $db_tar"
        continue
    fi

    for db_file in runinfo rundqm; do
        echo "--- ${run_id}.${db_file} ---"
        tar -xOzf "$db_tar" "${run_id}/${run_id}.${db_file}" 2>/dev/null \
            || echo "${run_id}.${db_file} not found in $db_tar"
    done
done < <(find . -type f -path '*/empty_event_list/*.log' -print0)
