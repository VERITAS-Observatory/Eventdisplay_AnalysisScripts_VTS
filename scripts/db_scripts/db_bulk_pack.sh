#!/bin/bash
# Pack DBTEXT directories created by db_bulk_export.py.

set -euo pipefail

if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 --output-dir <DBTEXT directory> [--remove-directories]"
    exit 0
fi

OUTPUT_DIR=""
REMOVE_DIRECTORIES=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --remove-directories)
            REMOVE_DIRECTORIES=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "${OUTPUT_DIR}" || ! -d "${OUTPUT_DIR}" ]]; then
    echo "A valid --output-dir is required" >&2
    exit 2
fi

while IFS= read -r -d '' run_dir; do
    run_id=$(basename "${run_dir}")
    parent_dir=$(dirname "${run_dir}")
    metadata="${run_id}/${run_id}.metadata.json"
    archive="${parent_dir}/${run_id}.tar.gz"
    temporary_archive="${archive}.$$"

    if [[ ! -f "${run_dir}/${run_id}.metadata.json" ]]; then
        echo "Missing metadata for ${run_dir}; not packing" >&2
        continue
    fi
    if grep -Fq '"export_scope": "mutable-fields-only"' "${run_dir}/${run_id}.metadata.json"; then
        echo "${run_dir} is a partial mutable-fields refresh; it must be merged into an existing complete package, not packed on its own" >&2
        continue
    fi
    if tar -czf "${temporary_archive}" -C "${parent_dir}" "${run_id}" \
        && tar -tzf "${temporary_archive}" "${metadata}" >/dev/null 2>&1 \
        && mv -f -- "${temporary_archive}" "${archive}"; then
        echo "Packed ${archive}"
        if [[ ${REMOVE_DIRECTORIES} -eq 1 ]]; then
            rm -rf -- "${run_dir}"
        fi
    else
        echo "Failed to pack ${run_dir}" >&2
        rm -f -- "${temporary_archive}"
    fi
done < <(find "${OUTPUT_DIR}" -mindepth 2 -maxdepth 2 -type d -name '[0-9][0-9][0-9]*' -print0)
