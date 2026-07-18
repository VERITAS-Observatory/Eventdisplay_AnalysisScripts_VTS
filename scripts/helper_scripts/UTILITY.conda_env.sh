#!/bin/bash
# Shared Conda setup and environment logging helpers for job scripts.

evndisp_ml_find_conda_exe()
{
    local default_conda="/afs/ifh.de/group/cta/scratch/maierg/software/miniforge3/bin/conda"

    if [[ -n "${CONDA_EXE:-}" && -x "${CONDA_EXE}" ]]; then
        echo "${CONDA_EXE}"
        return 0
    fi

    if command -v conda > /dev/null 2>&1; then
        command -v conda
        return 0
    fi

    if [[ -n "${EVNDISP_ML_CONDA_EXE:-}" && -x "${EVNDISP_ML_CONDA_EXE}" ]]; then
        echo "${EVNDISP_ML_CONDA_EXE}"
        return 0
    fi

    if [[ -x "${default_conda}" ]]; then
        echo "${default_conda}"
        return 0
    fi

    echo "Error: found no conda executable." >&2
    echo "Set CONDA_EXE or EVNDISP_ML_CONDA_EXE to a valid conda binary." >&2
    return 1
}

evndisp_ml_resolve_env_prefix()
{
    local env_name="${1:-${EVNDISP_ML_ENV:-eventdisplay_ml}}"
    local conda_exe
    local system_python

    conda_exe="$(evndisp_ml_find_conda_exe)" || return 1
    system_python="$(command -v python3 || command -v python)" || {
        echo "Error: neither python3 nor python is available to parse conda metadata." >&2
        return 1
    }

    "${conda_exe}" env list --json | "${system_python}" -c '
import json
import os
import sys

env_name = sys.argv[1]
target = os.path.sep + "envs" + os.path.sep + env_name
data = json.load(sys.stdin)
for prefix in data.get("envs", []):
    if prefix == env_name or prefix.endswith(target):
        print(prefix)
        sys.exit(0)
sys.exit(1)
' "${env_name}"
}

evndisp_ml_use_env_prefix()
{
    local env_prefix="$1"
    local env_name="${2:-${EVNDISP_ML_ENV:-eventdisplay_ml}}"

    if [[ -z "${env_prefix}" || ! -d "${env_prefix}" ]]; then
        echo "Error: invalid conda environment prefix '${env_prefix}'." >&2
        exit 1
    fi

    export CONDA_DEFAULT_ENV="${env_name}"
    export CONDA_PREFIX="${env_prefix}"
    export CONDA_NO_PLUGINS="${CONDA_NO_PLUGINS:-true}"
    export PATH="${env_prefix}/bin:${PATH}"

    echo "Using conda environment '${env_name}' at '${env_prefix}'"
}

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
    local conda_exe

    export CONDA_NO_PLUGINS="${CONDA_NO_PLUGINS:-true}"

    conda_exe="$(evndisp_ml_find_conda_exe)" || exit 1

    eval "$("${conda_exe}" shell.bash hook)"
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
    local env_prefix="$4"
    local snapshot_tag
    local snapshot_file
    local lock_dir
    local tmp_file
    local conda_exe

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
        conda_exe="$(evndisp_ml_find_conda_exe 2> /dev/null || true)"
        tmp_file="${snapshot_file}.$$"
        {
            echo "Conda environment: $env_name"
            [[ -n "$env_prefix" ]] && echo "Conda environment prefix: $env_prefix"
            echo "Python executable: $(command -v python)"
            python --version
            echo
            echo "pip freeze:"
            python -m pip freeze || echo "pip freeze failed"
            echo
            echo "conda list:"
            if [[ -n "$conda_exe" ]]; then
                if [[ -n "$env_prefix" ]]; then
                    "${conda_exe}" list -p "$env_prefix"
                else
                    "${conda_exe}" list -n "$env_name"
                fi
            else
                echo "conda executable not found"
            fi
        } > "$tmp_file" 2>&1
        mv "$tmp_file" "$snapshot_file"
        rmdir "$lock_dir"
    fi

    echo "Conda environment snapshot: $snapshot_file" >> "$logfile"
}
