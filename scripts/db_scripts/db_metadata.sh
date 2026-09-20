#!/bin/bash
#
# Functions for writing metadata manifests for DBTEXT run directories.
#

json_escape()
{
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "${value}"
}

json_string_or_null()
{
    if [[ -n "$1" ]]; then
        printf '"'
        json_escape "$1"
        printf '"'
    else
        printf 'null'
    fi
}

write_db_metadata()
{
    local run_dir="${1%/}"
    local run_id="$2"
    local extraction_start_utc="${3:-}"
    local extraction_end_utc="${4:-}"
    local db_server_start_utc="${5:-}"
    local db_server_end_utc="${6:-}"
    local overwrite="${7:-0}"
    local metadata_file="${run_dir}/${run_id}.metadata.json"
    local temporary_file="${metadata_file}.$$"
    local file relative_path checksum_line checksum file_size file_mtime mtime_utc
    local -a payload_files=()
    local overwrite_json metadata_created_utc
    local first_file=1

    if [[ ! -d "${run_dir}" ]]; then
        echo "Cannot write DB metadata: directory not found: ${run_dir}" >&2
        return 1
    fi

    if [[ "${overwrite}" == "1" ]]; then
        overwrite_json="true"
    else
        overwrite_json="false"
    fi

    metadata_created_utc=$(date -u +'%Y-%m-%dT%H:%M:%SZ') || return 1

    while IFS= read -r -d '' file
    do
        payload_files+=("${file}")
    done < <(find "${run_dir}" -type f \
        ! -name "$(basename "${metadata_file}")" \
        ! -name "$(basename "${temporary_file}")" \
        -print0 | sort -z)

    {
        printf '{\n'
        printf '  "metadata_version": 1,\n'
        printf '  "run_id": %s,\n' "${run_id}"
        printf '  "archive_filename": "%s.tar.gz",\n' "${run_id}"
        printf '  "metadata_created_utc": '
        json_string_or_null "${metadata_created_utc}"
        printf ',\n'
        printf '  "extraction": {\n'
        printf '    "started_utc": '
        json_string_or_null "${extraction_start_utc}"
        printf ',\n'
        printf '    "finished_utc": '
        json_string_or_null "${extraction_end_utc}"
        printf ',\n'
        printf '    "database_server_time_utc_start": '
        json_string_or_null "${db_server_start_utc}"
        printf ',\n'
        printf '    "database_server_time_utc_end": '
        json_string_or_null "${db_server_end_utc}"
        printf ',\n'
        printf '    "overwrite_requested": %s\n' "${overwrite_json}"
        printf '  },\n'
        printf '  "database_schemas": ["VERITAS", "VOFFLINE"],\n'
        printf '  "checksum_algorithm": "SHA-256",\n'
        printf '  "checksum_scope": "all payload files below; this metadata file is excluded",\n'
        printf '  "files": [\n'

        for file in "${payload_files[@]}"
        do
            relative_path="${file#"${run_dir}"/}"
            file_size=$(stat -c '%s' -- "${file}") || return 1
            file_mtime=$(stat -c '%Y' -- "${file}") || return 1
            mtime_utc=$(date -u -d "@${file_mtime}" +'%Y-%m-%dT%H:%M:%SZ') || return 1
            checksum_line=$(sha256sum -- "${file}") || return 1
            checksum="${checksum_line%% *}"

            if [[ ${first_file} -eq 0 ]]; then
                printf ',\n'
            fi
            first_file=0
            printf '    {"path": "'
            json_escape "${relative_path}"
            printf '", "size": %s, "mtime_utc": "' "${file_size}"
            json_escape "${mtime_utc}"
            printf '", "sha256": "'
            json_escape "${checksum}"
            printf '"}'
        done

        printf '\n  ]\n'
        printf '}\n'
    } > "${temporary_file}" || {
        rm -f -- "${temporary_file}"
        return 1
    }

    mv -f -- "${temporary_file}" "${metadata_file}"
}
