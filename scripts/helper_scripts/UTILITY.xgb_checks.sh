#!/bin/bash
# Checks for Eventdisplay-ML (XGB) job steps.
# Source this file; the functions return nonzero on failure so that callers can exit.

# Check the result of an Eventdisplay-ML apply step (stereo or classification sidecar).
# Removes the output file on failure, so that a partial sidecar is never used downstream.
#
# Arguments: <ML exit status> <output ROOT file> <log file>
evndisp_ml_check_apply()
{
    local ml_status="$1"
    local output="$2"
    local log="$3"
    local reason=""
    if [[ "$ml_status" -ne 0 ]]; then
        reason="Eventdisplay-ML exit status $ml_status"
    elif [[ ! -s "$output" ]]; then
        reason="missing or empty output file $output"
    elif ! grep -q "Total processed events written" "$log"; then
        reason="no completion message in $log"
    fi
    if [[ -n "$reason" ]]; then
        echo "ERROR: XGB apply step failed: $reason" | tee -a "$log"
        rm -f "$output"
        return 1
    fi
    echo "XGB apply step completed: $output"
}

# Check the result of an Eventdisplay-ML training step.
#
# Arguments: <ML exit status> <model file prefix (without .joblib/.joblib.gz)> <log file>
evndisp_ml_check_train()
{
    local ml_status="$1"
    local prefix="$2"
    local log="$3"
    local reason=""
    if [[ "$ml_status" -ne 0 ]]; then
        reason="Eventdisplay-ML exit status $ml_status"
    elif [[ ! -s "${prefix}.joblib.gz" ]] && [[ ! -s "${prefix}.joblib" ]]; then
        reason="missing or empty model ${prefix}.joblib(.gz)"
    fi
    if [[ -n "$reason" ]]; then
        echo "ERROR: XGB training step failed: $reason" | tee -a "$log"
        return 1
    fi
    echo "XGB training step completed: ${prefix}"
}
