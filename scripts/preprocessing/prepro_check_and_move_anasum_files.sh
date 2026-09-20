#!/bin/bash
# Check and move anasum files for all cuts
# This script should be used in the temporary data directories for cleanup and
# move of files to their final archive destination

ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
CUTLIST="anasum_hard2tel anasum_hard3tel anasum_moderate2tel anasum_soft2tel"
if [[ $ANATYPE == "NN" ]]; then
    CUTLIST="anasum_supersoftNN2tel"
fi

# Record run IDs for which exactly one of the expected anasum products is
# present.  The check is done before cleanup and moving so incomplete pairs
# are still visible in the temporary input directories.
INCOMPLETE_RUN_LIST="anasum_incomplete_run_ids.txt"
: > "$INCOMPLETE_RUN_LIST" || {
    echo "Error: unable to create $INCOMPLETE_RUN_LIST" >&2
    exit 1
}

check_anasum_pairs()
{
    local cut=$1
    local file
    local run
    local -A has_root=()
    local -A has_log=()

    shopt -s nullglob
    for file in "$cut"/*.anasum.root; do
        run=${file##*/}
        run=${run%.anasum.root}
        has_root["$run"]=1
    done
    for file in "$cut"/*.anasum.log; do
        run=${file##*/}
        run=${run%.anasum.log}
        has_log["$run"]=1
    done
    shopt -u nullglob

    for run in "${!has_root[@]}" "${!has_log[@]}"; do
        [[ -n $run ]] || continue
        if [[ -z ${has_root[$run]+present} || -z ${has_log[$run]+present} ]]; then
            printf '%s\n' "$run" >> "$INCOMPLETE_RUN_LIST"
            echo "Incomplete anasum pair in $cut: run $run (one of .anasum.root/.anasum.log is missing)" >&2
        fi
    done
}

for C in $CUTLIST; do
    check_anasum_pairs "$C"
done

# A run may be incomplete in more than one cut; keep the report as a unique
# list of run IDs.
sort -u "$INCOMPLETE_RUN_LIST" -o "$INCOMPLETE_RUN_LIST"

for C in $CUTLIST; do
    echo "$C"
    ./prepro_check_and_clean_files.sh "$C"
    ./prepro_move_preprocessed_files.sh "$C"
done
