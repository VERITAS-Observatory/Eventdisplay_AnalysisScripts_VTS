#!/bin/bash
# Shared Conda setup and environment logging helpers for job scripts.

evndisp_ml_setup_python_cache()
{
    local tempdir="$1"
    local cache_tag="$2"

    [[ -z "$tempdir" ]] && return

    cache_tag="${cache_tag//\//_}"
    export PYTHONPYCACHEPREFIX="${tempdir}/pycache_${cache_tag}"
    mkdir -p "$PYTHONPYCACHEPREFIX"
    echo "Python cache dir: $PYTHONPYCACHEPREFIX"
}

evndisp_ml_activate_conda()
{
    local env_name="${1:-${EVNDISP_ML_ENV:-eventdisplay_ml}}"

    export CONDA_NO_PLUGINS="${CONDA_NO_PLUGINS:-true}"

    if ! command -v conda > /dev/null 2>&1; then
        echo "Error: found no conda installation."
        echo "exiting..."
        exit 1
    fi

    eval "$(conda shell.bash hook)"
    if ! conda activate "$env_name"; then
        echo "Error: failed to activate conda environment '$env_name'."
        echo "exiting..."
        exit 1
    fi
    echo "Activated conda environment '$env_name'"
}

evndisp_ml_log_environment()
{
    local logfile="$1"
    local env_name="${2:-${EVNDISP_ML_ENV:-eventdisplay_ml}}"
    local snapshot_dir="$3"
    local snapshot_tag
    local snapshot_file
    local lock_dir
    local tmp_file

    {
        echo "Python executable: $(command -v python)"
        python --version
    } >> "$logfile" 2>&1

    [[ "${EVNDISP_ML_LOG_ENVIRONMENT:-snapshot}" == "none" ]] && return

    if [[ -z "$snapshot_dir" ]]; then
        python -m pip freeze >> "$logfile" 2>&1 \
            || echo "pip freeze failed, continuing" >> "$logfile"
        return
    fi

    mkdir -p "$snapshot_dir"
    snapshot_tag="${env_name//\//_}"
    snapshot_file="${snapshot_dir}/conda_environment_${snapshot_tag}.txt"
    lock_dir="${snapshot_file}.lock"

    if [[ -f "$snapshot_file" ]]; then
        echo "Conda environment snapshot: $snapshot_file" >> "$logfile"
        return
    fi

    if mkdir "$lock_dir" 2> /dev/null; then
        tmp_file="${snapshot_file}.$$"
        {
            echo "Conda environment: $env_name"
            echo "Python executable: $(command -v python)"
            python --version
            echo
            echo "pip freeze:"
            python -m pip freeze || echo "pip freeze failed"
            echo
            echo "conda list:"
            conda list
        } > "$tmp_file" 2>&1
        mv "$tmp_file" "$snapshot_file"
        rmdir "$lock_dir"
    fi

    echo "Conda environment snapshot: $snapshot_file" >> "$logfile"
}
