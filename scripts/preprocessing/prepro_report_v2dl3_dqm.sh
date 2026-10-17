#!/usr/bin/env bash
# Group V2DL3 failure runs using the status in their archived DQM record.
set -euo pipefail
usage() {
    cat <<'HELP'
Usage: prepro_report_v2dl3_dqm.sh [--output DIR] [DIRECTORY ...]

Scan error/ and empty_event_list/ directories recursively (default: v2dl3_*).
Read $VERITAS_DATA_DIR/shared/DBTEXT/<run ID divided by 10000>/<run>.tar.gz.
Write sorted unique run IDs to <status>.txt and per-file details to report.tsv.
Also list runs with usable_duration 00:00:00 in zero_usable_duration.txt.
Classify good_run records with observing_mode off as good_run_off.
Save full DQM and runinfo records for good runs in good_run_details.log.
Invalid DQM runs with data timestamps less than 120 seconds apart and run_status manually_ended are classified
as less_than_2_minutes using their .runinfo record. Other lookup failures use
missing_archive, unreadable_dqm, or invalid_dqm.
The output directory must not exist (default: v2dl3_dqm_report).
Input files and DQM archives are never modified. Requires Bash 4+, GNU find,
GNU sort, GNU date, tar, and awk. Lookup failures are reported without stopping the scan.
HELP
}
output=v2dl3_dqm_report
roots=()
while (($#)); do
    case $1 in
        -h|--help) usage; exit 0 ;;
        --output)
            if (($# < 2)) || [[ -z $2 ]]; then
                echo '--output requires a directory' >&2; exit 1
            fi
            output=$2; shift 2 ;;
        --) shift; roots+=("$@"); break ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *) roots+=("$1"); shift ;;
    esac
done
: "${VERITAS_DATA_DIR:?Set VERITAS_DATA_DIR to the VERITAS data directory}"
if ((${#roots[@]} == 0)); then
    shopt -s nullglob
    roots=(v2dl3_*)
fi
if ((${#roots[@]} == 0)); then
    echo 'No input directories found' >&2; exit 1
fi
for root in "${roots[@]}"; do
    [[ -d $root ]] || { echo "Not a directory: $root" >&2; exit 1; }
done
# Materialize discovery so a failed find cannot silently produce a partial scan.
files=$(mktemp)
trap 'rm -f -- "$files"' EXIT
for i in "${!roots[@]}"; do
    [[ ${roots[i]} = /* ]] || roots[i]=./${roots[i]}
done
for root in "${roots[@]}"; do
    printf 'Scanning directory: %s\n' "$root" >&2
done
find "${roots[@]}" -type f \( -path '*/error/*' -o -path '*/empty_event_list/*' \) -print0 > "$files"
mkdir -- "$output"
printf 'run_id\tstatus\tstatus_reason\tsource\n' > "$output/report.tsv"
declare -A statuses reasons
while IFS= read -r -d '' path; do
    name=${path##*/}
    run=${name%%.*}
    if [[ ! $run =~ ^[0-9]+$ ]]; then
        printf 'Skipping filename without a run ID: %s\n' "$path" >&2
        continue
    fi
    if [[ ! ${statuses[$run]+present} ]]; then
        archive=$VERITAS_DATA_DIR/shared/DBTEXT/$((10#$run / 10000))/$run.tar.gz
        status=missing_archive
        reason='Archive not found'
        if [[ -e $archive ]]; then
            if record=$(tar -xzOf "$archive" "$run/$run.rundqm" 2>/dev/null); then
                # Resolve columns by name; require exactly one matching run row.
                if parsed=$(awk -F '|' -v run="$run" '
                    NR == 1 {
                        sub(/\r$/, "")
                        for (i = 1; i <= NF; i++) col[$i] = i
                        if (!col["run_id"] || !col["status"]) exit 1
                        next
                    }
                    {
                        sub(/\r$/, "")
                        if ($(col["run_id"]) == run) {
                            count++
                            status = $(col["status"])
                            reason = col["status_reason"] ? $(col["status_reason"]) : ""
                            zero_duration = col["usable_duration"] && $(col["usable_duration"]) == "00:00:00"
                        }
                    }
                    END {
                        if (count != 1 || status !~ /^[a-zA-Z0-9_][a-zA-Z0-9_-]*$/ || status == "NULL") exit 1
                        gsub(/\t/, " ", reason)
                        printf "%s\t%s\t%d", status, reason, zero_duration
                    }' <<< "$record"); then
                    status=${parsed%%$'\t'*}
                    details=${parsed#*$'\t'}
                    reason=${details%$'\t'*}
                    if [[ ${details##*$'\t'} == 1 ]]; then
                        printf '%s\n' "$run" >> "$output/zero_usable_duration.txt"
                    fi
                else
                    status=invalid_dqm
                    reason='Missing, duplicate, or invalid run/status fields'
                fi
            else
                status=unreadable_dqm
                reason='Cannot extract run DQM record'
            fi
        fi
        if [[ $status == invalid_dqm ]] && info=$(tar -xzOf "$archive" "$run/$run.runinfo" 2>/dev/null); then
            if times=$(awk -F '|' -v run="$run" '
                NR == 1 {
                    sub(/\r$/, "")
                    for (i = 1; i <= NF; i++) col[$i] = i
                    if (!col["run_id"] || !col["data_start_time"] || !col["data_end_time"] || !col["run_status"]) exit 1
                    next
                }
                {
                    sub(/\r$/, "")
                    if ($(col["run_id"]) == run) {
                        count++
                        start = $(col["data_start_time"])
                        end = $(col["data_end_time"])
                        run_status = $(col["run_status"])
                    }
                }
                END {
                    if (count != 1 || run_status != "manually_ended" || start !~ /^[0-9][0-9][0-9][0-9]-/ || end !~ /^[0-9][0-9][0-9][0-9]-/) exit 1
                    printf "%s\t%s", start, end
                }' <<< "$info") &&
                start_seconds=$(date -u -d "${times%%$'\t'*}" +%s 2>/dev/null) &&
                end_seconds=$(date -u -d "${times#*$'\t'}" +%s 2>/dev/null); then
                seconds=$((end_seconds - start_seconds))
                if ((seconds >= 0 && seconds < 120)); then
                    status=less_than_2_minutes
                    reason="Invalid DQM; manually_ended; runinfo data duration: $seconds seconds"
                fi
            fi
        fi
        if [[ $status == good_run ]] && info=$(tar -xzOf "$archive" "$run/$run.runinfo" 2>/dev/null); then
            if awk -F '|' -v run="$run" '
                NR == 1 {
                    sub(/\r$/, "")
                    for (i = 1; i <= NF; i++) col[$i] = i
                    if (!col["run_id"] || !col["observing_mode"]) exit 1
                    next
                }
                {
                    sub(/\r$/, "")
                    if ($(col["run_id"]) == run) {
                        count++
                        mode = $(col["observing_mode"])
                    }
                }
                END { if (count != 1 || mode != "off") exit 1 }
            ' <<< "$info"; then
                status=good_run_off
            fi
        fi
        statuses[$run]=$status
        reasons[$run]=$reason
        printf '%s\n' "$run" >> "$output/$status.txt"
    fi
    printf '%s\t%s\t%s\t%s\n' "$run" "${statuses[$run]}" "${reasons[$run]}" "$path" >> "$output/report.tsv"
done < "$files"
# A good run must not occur in any other category list.
if [[ -f $output/good_run.txt ]]; then
    other_lists=()
    for list in "$output"/*.txt; do
        [[ $list == "$output/good_run.txt" ]] || other_lists+=("$list")
    done
    good_runs=$(awk -v good="$output/good_run.txt" '
        FILENAME != good { excluded[$0] = 1; next }
        !($0 in excluded) { print }
    ' "${other_lists[@]}" "$output/good_run.txt")
    : > "$output/good_run.txt"
    if [[ -n $good_runs ]]; then
        printf '%s\n' "$good_runs" > "$output/good_run.txt"
    fi
fi
for list in "$output"/*.txt; do
    [[ -e $list ]] || continue
    sort -n -u -o "$list" "$list"
    printf '%s: %s runs\n' "${list##*/}" "$(wc -l < "$list")"
done
# Dump only the final, mutually exclusive good-run selection.
: > "$output/good_run_details.log"
if [[ -f $output/good_run.txt ]]; then
    while IFS= read -r run; do
        archive=$VERITAS_DATA_DIR/shared/DBTEXT/$((10#$run / 10000))/$run.tar.gz
        {
            printf '========== Run %s ==========\nArchive: %s\n' "$run" "$archive"
            for kind in rundqm runinfo; do
                printf '\n--- %s/%s.%s ---\n' "$run" "$run" "$kind"
                if record=$(tar -xzOf "$archive" "$run/$run.$kind" 2>/dev/null); then
                    printf '%s\n' "$record"
                else
                    printf '[Could not extract %s record]\n' "$kind"
                fi
            done
            printf '\n'
        } >> "$output/good_run_details.log"
    done < "$output/good_run.txt"
fi
printf 'Good-run records: %s/good_run_details.log\n' "$output"
printf 'Report: %s/report.tsv\n' "$output"
