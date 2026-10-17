#!/usr/bin/env bash
# Quarantine runs selected by either DQM report, preserving real directories.
set -euo pipefail
base=''
reports=''
dry_run=false
remove_local_dl3=false
local_directory=$PWD
while (($#)); do
    case $1 in
        --base|--reports)
            if (($# < 2)) || [[ -z $2 || $2 == --* ]]; then
                echo "$1 requires a directory" >&2
                exit 1
            fi
            if [[ $1 == --base ]]; then base=$2; else reports=$2; fi
            shift 2 ;;
        --remove-local-dl3) remove_local_dl3=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help)
            echo 'Usage: bash prepro_move_do_not_use_files.sh --base AP_DIR --reports REPORT_DIR [--dry-run] [--remove-local-dl3]'
            echo 'Move runs from do_not_use.txt, zero_usable_duration.txt, and less_than_2_minutes.txt into AP_DIR/do_not_use.'
            echo '  --remove-local-dl3  Also delete selected run files in ./v2dl3_*/*/*/ relative to the invocation directory; skip symlinks.'
            echo '  --dry-run  Print proposed directory creation and file moves without changing anything.'
            exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done
[[ -n $base && -n $reports ]] || {
    echo 'Both --base and --reports are required' >&2; exit 1
}
printf 'Base directory: %s\nReports directory: %s\n' "$base" "$reports"
if $dry_run; then echo 'Mode: dry run (no changes)'; else echo 'Mode: move files'; fi
[[ -d $reports && -r $reports && -x $reports ]] || {
    echo "Cannot read report directory: $reports" >&2; exit 1
}
declare -A runs
for list in "$reports/do_not_use.txt" "$reports/zero_usable_duration.txt" "$reports/less_than_2_minutes.txt"; do
    printf 'Reading run list: %s\n' "$list"
    [[ -e $list || -L $list ]] || continue
    [[ -f $list && -r $list ]] || { echo "Cannot read: $list" >&2; exit 1; }
    while IFS= read -r run || [[ -n $run ]]; do
        [[ $run =~ ^[0-9]+$ ]] || { echo "Invalid run ID in $list: $run" >&2; exit 1; }
        runs[$run]=1
    done < "$list"
done
printf 'Run lists loaded.\n'
cd -- "$base"
# Refuse destination symlinks, including those left by earlier invocations.
if [[ -L do_not_use || ( -e do_not_use && ! -d do_not_use ) ]]; then
    echo 'do_not_use must be a real directory' >&2; exit 1
fi
# The layout is data_type/run_group/files; do not walk recursively.
shopt -s nullglob
make_directory() {
    if $dry_run; then
        printf 'Would run: mkdir -p %s\n' "$1"
    else
        printf 'mkdir -p %s\n' "$1"
        mkdir -p -- "$1"
    fi
}
for directory in ./anasum_* ./dl3_* ./mscw ./evndisp; do
    [[ -d $directory && ! -L $directory ]] || continue
    printf 'Processing data directory: %s\n' "$directory"
    make_directory "./do_not_use/${directory#./}"
    for group in "$directory"/*; do
        [[ ${group##*/} =~ ^[0-9]+$ ]] || continue
        [[ -d $group && ! -L $group ]] || continue
        printf 'Processing run group: %s\n' "$group"
        make_directory "./do_not_use/${group#./}"
        for path in "$group"/*; do
            name=${path##*/}
            # Filter names before stat: only selected runs need filesystem checks.
            [[ $name =~ ^([0-9]+)([^0-9]|$) ]] || continue
            run=${BASH_REMATCH[1]}
            [[ ${runs[$run]+present} ]] || continue
            [[ ! -L $path && -f $path ]] || continue
            target=./do_not_use/${path#./}
            if [[ -e $target || -L $target ]]; then
                printf 'Skipping existing destination: %s\n' "$target"
                continue
            fi
            if $dry_run; then
                printf 'Would move run %s: %s -> %s\n' "$run" "$path" "$target"
            else
                mv -n -- "$path" "$target"
                if [[ ! -e $path ]]; then
                    printf 'Moved run %s: %s -> %s\n' "$run" "$path" "$target"
                fi
            fi
        done
    done
done
if $remove_local_dl3; then
    # Local layout: v2dl3 configuration / analysis mode / category / run files.
    cd -- "$local_directory"
    for directory in ./v2dl3_*; do
        [[ -d $directory && ! -L $directory ]] || continue
        for mode in "$directory"/*; do
            [[ -d $mode && ! -L $mode ]] || continue
            for category in "$mode"/*; do
                [[ -d $category && ! -L $category ]] || continue
                for path in "$category"/*; do
                    name=${path##*/}
                    [[ $name =~ ^([0-9]+)([^0-9]|$) ]] || continue
                    run=${BASH_REMATCH[1]}
                    [[ ${runs[$run]+present} ]] || continue
                    [[ ! -L $path && -f $path ]] || continue
                    if $dry_run; then
                        printf 'Would remove run %s: %s\n' "$run" "$path"
                    else
                        rm -- "$path"
                        printf 'Removed run %s: %s\n' "$run" "$path"
                    fi
                done
            done
        done
    done
fi
echo 'Processing complete.'
