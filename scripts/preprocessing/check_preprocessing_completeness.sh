#!/usr/bin/env bash
# Check completeness of a large preprocessing production.

set -u
set -o pipefail

usage()
{
    cat <<'EOF'
Usage: check_preprocessing_completeness.sh <production-directory> [report-directory] [reference-subdirectory]

Check every baseline <run>.root file against the standard evndisp, mscw, anasum,
and DL3 products. Reports are written to the optional report directory. The
reference subdirectory defaults to 'evndisp'.
EOF
}

if [[ $# -lt 1 || $# -gt 3 || ${1:-} == "-h" || ${1:-} == "--help" ]]; then
    usage
    exit 2
fi

if [[ ! -d "$1" || ! -r "$1" || ! -x "$1" ]]; then
    echo "Error: production directory '$1' is not a readable directory" >&2
    exit 2
fi

ROOT=$(cd "$1" && pwd -P) || exit 2
REFERENCE_SUBDIR=${3:-evndisp}
case "/$REFERENCE_SUBDIR/" in
    //|/*/../*|*/./*|//*)
        echo "Error: reference subdirectory must be a non-empty relative path without '.' or '..' components" >&2
        exit 2
        ;;
esac
REFERENCE_DIR="$ROOT/$REFERENCE_SUBDIR"
if [[ ! -d "$REFERENCE_DIR" || ! -r "$REFERENCE_DIR" || ! -x "$REFERENCE_DIR" ]]; then
    echo "Error: reference directory '$REFERENCE_DIR' is not a readable directory" >&2
    exit 2
fi

if [[ $# -ge 2 ]]; then
    REPORT=$2
else
    REPORT="$ROOT/preprocessing-completeness-$(date +%Y%m%dT%H%M%S)"
fi

if ! mkdir -p "$REPORT"; then
    echo "Error: cannot create report directory '$REPORT'" >&2
    exit 2
fi
if [[ ! -d "$REPORT" || ! -w "$REPORT" ]]; then
    echo "Error: report directory '$REPORT' is not writable" >&2
    exit 2
fi

# Edit this list when a new standard cut is introduced.
CUTS=(hard2tel hard3tel moderate2tel soft2tel)

TARGET_NAMES=(evndisp mscw)
TARGET_REGEXES=('^([0-9]+)\.root$' '^([0-9]+)\.mscw\.root$')
TARGET_GLOBS=('*.root' '*.mscw.root')

for cut in "${CUTS[@]}"; do
    TARGET_NAMES+=("anasum_${cut}")
    TARGET_REGEXES+=('^([0-9]+)\.anasum\.root$')
    TARGET_GLOBS+=('*.anasum.root')
done

for mode in pointlike fullenclosure; do
    for all_events in '' '-all-events'; do
        for cut in "${CUTS[@]}"; do
            TARGET_NAMES+=("dl3_${mode}${all_events}_${cut}")
            TARGET_REGEXES+=('^([0-9]+)\.fits\.gz$')
            TARGET_GLOBS+=('*.fits.gz')
        done
    done
done

TMP_WORK=$(mktemp -d "${TMPDIR:-/tmp}/check-preprocessing-completeness.XXXXXX") || {
    echo "Error: cannot create temporary working directory" >&2
    exit 2
}
# shellcheck disable=SC2329  # invoked indirectly by trap
cleanup()
{
    rm -rf "$TMP_WORK"
}
trap cleanup EXIT HUP INT TERM

export LC_ALL=C

EXPECTED_RAW="$TMP_WORK/expected.raw.tsv"
EXPECTED_RUNS="$TMP_WORK/expected-runs.txt"
EXPECTED_PATHS="$TMP_WORK/expected-paths.tsv"
BASELINE_PATHS0="$TMP_WORK/baseline-paths.null"
BASELINE_DUPLICATES="$REPORT/baseline-duplicates.tsv"
BASELINE_DUPLICATES_RUNS="$TMP_WORK/baseline-duplicate-runs.txt"
: > "$EXPECTED_RAW"
: > "$EXPECTED_PATHS"

filesystem_error=0
if ! find "$REFERENCE_DIR" -type f -name '*.root' -print0 > "$BASELINE_PATHS0"; then
    echo "Error: reference traversal failed for '$REFERENCE_DIR'" >&2
    filesystem_error=1
fi

while IFS= read -r -d '' path; do
    name=${path##*/}
    if [[ "$name" =~ ^([0-9]+)\.root$ ]]; then
        run=${BASH_REMATCH[1]}
        printf '%s\t%s\n' "$run" "$path" >> "$EXPECTED_PATHS"
        printf '%s\n' "$run" >> "$EXPECTED_RAW"
    fi
done < "$BASELINE_PATHS0"

sort -u "$EXPECTED_RAW" > "$EXPECTED_RUNS"
awk -F '\t' '{ count[$1]++ } END { for (run in count) if (count[run] > 1) print run }' \
    "$EXPECTED_PATHS" | sort -u > "$BASELINE_DUPLICATES_RUNS"
: > "$BASELINE_DUPLICATES"
if [[ -s "$BASELINE_DUPLICATES_RUNS" ]]; then
    awk -F '\t' 'NR == FNR { duplicate[$1] = 1; next } duplicate[$1] { print }' \
        "$BASELINE_DUPLICATES_RUNS" "$EXPECTED_PATHS" | sort -t $'\t' -k1,1 -k2,2 > "$BASELINE_DUPLICATES"
fi

expected_count=$(wc -l < "$EXPECTED_RUNS" | tr -d '[:space:]')
baseline_duplicate_count=$(wc -l < "$BASELINE_DUPLICATES_RUNS" | tr -d '[:space:]')

if [[ "$expected_count" -eq 0 ]]; then
    echo "Error: no baseline files matching <run>.root found below '$REFERENCE_DIR'" >&2
    exit 2
fi

SUMMARY="$REPORT/summary.tsv"
cat > "$SUMMARY" <<'EOF'
target	status	expected	present	missing	unexpected	duplicate_runs
EOF
printf 'Baseline runs: %s\n' "$expected_count"
if [[ "$baseline_duplicate_count" -gt 0 ]]; then
    printf 'Baseline duplicate runs: %s (see %s)\n' "$baseline_duplicate_count" "$BASELINE_DUPLICATES"
fi

incomplete=0
if [[ "$baseline_duplicate_count" -gt 0 ]]; then
    incomplete=1
fi

for index in "${!TARGET_NAMES[@]}"; do
    target=${TARGET_NAMES[$index]}
    target_dir="$ROOT/$target"
    target_runs0="$TMP_WORK/${target}.paths.null"
    target_paths="$TMP_WORK/${target}.paths.tsv"
    target_runs="$TMP_WORK/${target}.runs.txt"
    duplicate_runs="$TMP_WORK/${target}.duplicate-runs.txt"
    missing_report="$REPORT/missing-${target}.txt"
    unexpected_report="$REPORT/unexpected-${target}.txt"
    duplicate_report="$REPORT/duplicates-${target}.tsv"
    : > "$target_paths"
    : > "$target_runs"
    : > "$duplicate_runs"
    : > "$missing_report"
    : > "$unexpected_report"
    : > "$duplicate_report"

    if [[ ! -d "$target_dir" || ! -r "$target_dir" || ! -x "$target_dir" ]]; then
        cp "$EXPECTED_RUNS" "$missing_report"
        printf '%s\tmissing-directory\t%s\t0\t%s\t0\t0\n' \
            "$target" "$expected_count" "$expected_count" >> "$SUMMARY"
        printf '%-42s missing directory\n' "$target"
        incomplete=1
        continue
    fi

    if ! find "$target_dir" -type f -name "${TARGET_GLOBS[$index]}" -print0 > "$target_runs0"; then
        echo "Error: traversal failed for '$target_dir'" >&2
        filesystem_error=1
    fi

    while IFS= read -r -d '' path; do
        name=${path##*/}
        if [[ "$name" =~ ${TARGET_REGEXES[$index]} ]]; then
            run=${BASH_REMATCH[1]}
            printf '%s\t%s\n' "$run" "$path" >> "$target_paths"
            printf '%s\n' "$run" >> "$target_runs"
        fi
    done < "$target_runs0"

    sort -u "$target_runs" -o "$target_runs"
    awk -F '\t' '{ count[$1]++ } END { for (run in count) if (count[run] > 1) print run }' \
        "$target_paths" | sort -u > "$duplicate_runs"
    if [[ -s "$duplicate_runs" ]]; then
        awk -F '\t' 'NR == FNR { duplicate[$1] = 1; next } duplicate[$1] { print }' \
            "$duplicate_runs" "$target_paths" | sort -t $'\t' -k1,1 -k2,2 > "$duplicate_report"
    fi

    comm -23 "$EXPECTED_RUNS" "$target_runs" > "$missing_report"
    comm -13 "$EXPECTED_RUNS" "$target_runs" > "$unexpected_report"
    missing_count=$(wc -l < "$missing_report" | tr -d '[:space:]')
    unexpected_count=$(wc -l < "$unexpected_report" | tr -d '[:space:]')
    duplicate_count=$(wc -l < "$duplicate_runs" | tr -d '[:space:]')
    present_count=$((expected_count - missing_count))
    status=ok
    if [[ "$missing_count" -gt 0 || "$duplicate_count" -gt 0 ]]; then
        status=incomplete
        incomplete=1
    fi
    if [[ "$unexpected_count" -gt 0 ]]; then
        status=${status/ok/warning}
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$target" "$status" "$expected_count" "$present_count" "$missing_count" \
        "$unexpected_count" "$duplicate_count" >> "$SUMMARY"
    printf '%-42s %s (present %s, missing %s, unexpected %s, duplicates %s)\n' \
        "$target" "$status" "$present_count" "$missing_count" "$unexpected_count" "$duplicate_count"
done

cat > "$REPORT/README" <<EOF
This report was generated by check_preprocessing_completeness.sh.
Reference directory: $REFERENCE_DIR

summary.tsv columns are target, status, expected, present, missing, unexpected,
and duplicate_runs. Missing and unexpected files contain one run number per line.
Duplicate TSV files contain the run number and every matching pathname. A run is
present when at least one regular file with the target's exact expected basename
exists anywhere below its target directory; shard-directory placement is ignored.
Baseline files are exact numeric <run>.root basenames below the evndisp reference
directory (<production-directory>/evndisp).
EOF

printf 'Reports: %s\n' "$REPORT"
if [[ "$filesystem_error" -ne 0 ]]; then
    exit 2
fi
if [[ "$incomplete" -ne 0 ]]; then
    exit 1
fi
exit 0
