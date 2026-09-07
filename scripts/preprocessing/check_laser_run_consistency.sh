#!/bin/bash
# Compare Laser/Flasher runs reported by evndisp logs with DBTEXT laserrun files.
#
# Usage:
#   check_laser_run_consistency.sh <processed evndisp directory> <DBTEXT directory> [output file]
#
# The laserrun excluded_telescopes value is a bit mask:
#   bit 0 -> T1, bit 1 -> T2, bit 2 -> T3, bit 3 -> T4.
# A laser row applies to telescope T when the corresponding bit is not set.

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 2 || $# -gt 3 || "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 <processed evndisp directory> <DBTEXT directory> [output file]" >&2
    echo "Example: $0 \"\$VERITAS_DATA_DIR/shared/processed_data_v490.7/AP/evndisp\" \"\$VERITAS_DATA_DIR/shared/DBTEXT\" discrepancies.tsv" >&2
    exit 2
fi

PROCESSED_DIR=${1%/}
DBTEXT_DIR=${2%/}
OUTPUT_FILE=${3:-laser_run_discrepancies.tsv}

if [[ ! -d ${PROCESSED_DIR} ]]; then
    echo "Processed-data directory not found: ${PROCESSED_DIR}" >&2
    exit 1
fi
if [[ ! -d ${DBTEXT_DIR} ]]; then
    echo "DBTEXT directory not found: ${DBTEXT_DIR}" >&2
    exit 1
fi

mkdir -p "$(dirname "${OUTPUT_FILE}")"
printf 'run_id\ttelescope\tlog_laser_run\tdb_laser_run(s)\treason\tlog_file\tarchive\n' > "${OUTPUT_FILE}"

run_subdirectory()
{
    local run_id=$1
    if (( run_id < 100000 )); then
        printf '%s' "${run_id:0:1}"
    else
        printf '%s' "${run_id:0:2}"
    fi
}

report()
{
    local run_id=$1
    local telescope=$2
    local log_run=$3
    local db_runs=$4
    local reason=$5
    local log_file=$6
    local archive=$7
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${run_id}" "${telescope}" "${log_run}" "${db_runs}" "${reason}" \
        "${log_file}" "${archive}" >> "${OUTPUT_FILE}"
    discrepancies=$((discrepancies + 1))
}

discrepancies=0
logs_checked=0
logs_with_laser_line=0

while IFS= read -r -d '' log_file; do
    log_name=$(basename "${log_file}")
    if [[ ${log_name} =~ ^([0-9]+)\.log$ ]]; then
        run_id=${BASH_REMATCH[1]}
    else
        # Ignore files such as 110150.ped.log and 110133.tzero.log.
        continue
    fi
    logs_checked=$((logs_checked + 1))
    subdirectory=$(run_subdirectory "${run_id}")
    archive="${DBTEXT_DIR}/${subdirectory}/${run_id}.tar.gz"
    member="${run_id}/${run_id}.laserrun"

    laser_line=$(awk '/Laser\/Flasher runs:/ { line=$0 } END { if (line != "") print line }' "${log_file}")
    if [[ -z ${laser_line} ]]; then
        report "${run_id}" "-" "-" "-" "missing_log_line" "${log_file}" "${archive}"
        continue
    fi
    logs_with_laser_line=$((logs_with_laser_line + 1))

    # Keep this pattern deliberately strict: the log must contain one integer
    # for each telescope in the known evndisp output format.
    pattern='Laser/Flasher runs:[[:space:]]*T1:[[:space:]]*([0-9]+)[[:space:]]+T2:[[:space:]]*([0-9]+)[[:space:]]+T3:[[:space:]]*([0-9]+)[[:space:]]+T4:[[:space:]]*([0-9]+)'
    if [[ ! ${laser_line} =~ ${pattern} ]]; then
        report "${run_id}" "-" "-" "-" "malformed_log_line" "${log_file}" "${archive}"
        continue
    fi
    log_runs=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}")

    if [[ ! -f ${archive} ]]; then
        report "${run_id}" "-" "-" "-" "missing_archive" "${log_file}" "${archive}"
        continue
    fi

    if ! archive_members=$(tar -tzf "${archive}" 2>/dev/null); then
        report "${run_id}" "-" "-" "-" "unreadable_archive" "${log_file}" "${archive}"
        continue
    fi
    if ! grep -Fqx "${member}" <<< "${archive_members}"; then
        report "${run_id}" "-" "-" "-" "missing_laserrun_file" "${log_file}" "${archive}"
        continue
    fi
    if ! laserrun=$(tar -xOzf "${archive}" "${member}" 2>/dev/null); then
        report "${run_id}" "-" "-" "-" "unreadable_laserrun_file" "${log_file}" "${archive}"
        continue
    fi

    db_runs_for_telescope=()
    while IFS='|' read -r laser_id excluded_telescopes _config_mask; do
        [[ ${laser_id} == "run_id" || -z ${laser_id} ]] && continue
        if [[ ! ${laser_id} =~ ^[0-9]+$ || ! ${excluded_telescopes} =~ ^[0-9]+$ ]]; then
            report "${run_id}" "-" "-" "-" "malformed_laserrun_row" "${log_file}" "${archive}"
            db_runs_for_telescope=()
            break
        fi
        for telescope_number in 1 2 3 4; do
            bit=$((1 << (telescope_number - 1)))
            if (( (excluded_telescopes & bit) == 0 )); then
                db_runs_for_telescope[${telescope_number}]+="${laser_id} "
            fi
        done
    done <<< "${laserrun}"

    if [[ ${#db_runs_for_telescope[@]} -eq 0 ]]; then
        continue
    fi
    for telescope_number in 1 2 3 4; do
        db_candidates=${db_runs_for_telescope[${telescope_number}]-}
        db_candidates=${db_candidates% }
        if [[ -z ${db_candidates} ]]; then
            report "${run_id}" "T${telescope_number}" "${log_runs[$((telescope_number - 1))]}" "-" \
                "no_eligible_laser_run" "${log_file}" "${archive}"
        elif [[ ${db_candidates} == *' '* ]]; then
            report "${run_id}" "T${telescope_number}" "${log_runs[$((telescope_number - 1))]}" \
                "${db_candidates}" "multiple_eligible_laser_runs" "${log_file}" "${archive}"
        elif [[ ${log_runs[$((telescope_number - 1))]} != ${db_candidates} ]]; then
            report "${run_id}" "T${telescope_number}" "${log_runs[$((telescope_number - 1))]}" \
                "${db_candidates}" "different_laser_run" "${log_file}" "${archive}"
        fi
    done
done < <(find "${PROCESSED_DIR}" -type f -name '*.log' -print0 | sort -z)

echo "Checked ${logs_checked} run logs (${logs_with_laser_line} with Laser/Flasher lines)." >&2
echo "Found ${discrepancies} discrepancies; report: ${OUTPUT_FILE}" >&2
[[ ${discrepancies} -eq 0 ]]
