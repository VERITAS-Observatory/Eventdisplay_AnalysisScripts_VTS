#!/bin/bash
# Shared job submission utility.
# Source this file to use submit_job() and run_parallel_jobs().
#
# submit_job <fscript> [parallel_line [parallel_file]]
#   fscript:       full path to the script to submit
#   parallel_line: command to write in parallel mode (default: "$fscript")
#   parallel_file: file to collect parallel jobs in (default: "$LOGDIR/runscripts.dat")
# Sets: JOBID (qsub mode only)
# Requires env: SUBC, LOGDIR, h_vmem, tmpdir_size, EVNDISPSCRIPTS
# Optional env: ncore (HTCondor CPU request; default: 1)
submit_job() {
    local fscript="$1"
    local parallel_line="${2:-$fscript}"
    local parallel_file="${3:-$LOGDIR/runscripts.dat}"
    local subc_dir
    subc_dir="$(dirname "${BASH_SOURCE[0]}")"
    # Word-split $SUBC into array for safe expansion (SUBC is a pre-expanded command string)
    read -ra subc_arr <<< "$SUBC"

    if [[ "$SUBC" == *qsub* ]]; then
        JOBID=$("${subc_arr[@]}" "$fscript")
        # account for -terse changing the job number format
        if [[ "$SUBC" != *-terse* ]]; then
            echo "without -terse!"
            JOBID=$(echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }')
        fi
    elif [[ "$SUBC" == *condor_submit* ]]; then
        "$subc_dir/UTILITY.condorSubmission.sh" "$fscript" "${h_vmem-}" "${tmpdir_size-}" "${ncore:-1}"
        condor_submit "$fscript.condor"
    elif [[ "$SUBC" == *condor* ]]; then
        "$subc_dir/UTILITY.condorSubmission.sh" "$fscript" "${h_vmem-}" "${tmpdir_size-}" "${ncore:-1}"
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} ${CONDOR_SUBMIT_ARGS:-submit}"
        echo "-------------------------------------------------------------------------------"
    elif [[ "$SUBC" == *sbatch* ]]; then
        "${subc_arr[@]}" "$fscript"
    elif [[ "$SUBC" == *parallel* ]]; then
        echo "$parallel_line" >> "$parallel_file"
    elif [[ "$SUBC" == *simple* ]]; then
        local logfile="${fscript%.sh}.log"
        "$fscript" |& tee "$logfile"
    elif [[ "$SUBC" == *test* ]]; then
        echo "TESTING SCRIPT $fscript"
    fi
}

# run_parallel_jobs [parallel_file]
#   parallel_file: file containing parallel jobs (default: "$LOGDIR/runscripts.dat")
# Requires env: SUBC
run_parallel_jobs() {
    [[ "$SUBC" != *parallel* ]] && return
    local parallel_file="${1:-$LOGDIR/runscripts.dat}"
    read -ra subc_arr <<< "$SUBC"
    sort -u "$parallel_file" | "${subc_arr[@]}"
}
