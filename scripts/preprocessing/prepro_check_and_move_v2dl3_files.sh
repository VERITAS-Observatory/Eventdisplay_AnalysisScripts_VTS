#!/bin/bash
# Check and move v2dl3 files for all available cuts and products in batches.

if [[ $# -gt 1 || ( $# -eq 1 && ( ! $1 =~ ^[1-9][0-9]*$ || $1 -gt 1000 ) ) ]]; then
    echo "Usage: $0 [batch size (1-1000)]" >&2
    exit 2
fi

BATCH_SIZE=${1:-1000}

script_dir=$(dirname "$(realpath "$0")")
BATCH_RESULT=$(mktemp "${TMPDIR:-/tmp}/prepro-v2dl3-batch.XXXXXX") || {
    echo "Error: unable to create temporary batch result file" >&2
    exit 1
}
trap 'rm -f "$BATCH_RESULT"' EXIT

# Move all products belonging to a failed log to the product's error directory.
move_products_to_error()
{
    local log_file=$1
    local source_dir=${log_file%/*}
    local stem=${log_file##*/}
    local error_dir

    stem=${stem%.log}
    error_dir="$source_dir/error"
    mkdir -p "$error_dir"

    for product in "$source_dir/$stem".*; do
        [[ -f "$product" ]] || continue
        mv -f "$product" "$error_dir/"
    done
}

# Remove stale error products when a later check confirms a clean log.
clean_error_products()
{
    local log_file=$1
    local source_dir=${log_file%/*}
    local stem=${log_file##*/}
    local error_dir

    stem=${stem%.log}
    error_dir="$source_dir/error"
    [[ -d "$error_dir" ]] || return 0

    for product in "$error_dir/$stem".*; do
        [[ -f "$product" ]] || continue
        rm -f "$product"
    done
}

shopt -s nullglob
for C in v2dl3_*/; do
    C=${C%/}
    CUT=${C#v2dl3_}
    for A in "$C"/*/; do
        A=${A%/}
        PRODUCT=${A##*/}
        [[ $PRODUCT == "error" ]] && continue
        DDIR=${PRODUCT/full-enclosure/fullenclosure}
        DDIR=${DDIR/point-like/pointlike}
        DDIR=dl3_${DDIR}_${CUT}
        LOGS=("$A"/*.log)
        NLOG=${#LOGS[@]}
        echo "Source directory: $A Target directory: $DDIR ($NLOG logs, batches of $BATCH_SIZE)"

        for ((offset = 0; offset < NLOG; offset += BATCH_SIZE)); do
            LOG_BATCH=()
            for ((i = offset; i < NLOG && i < offset + BATCH_SIZE; i++)); do
                LOG_BATCH+=("${LOGS[i]}")
            done

            VALID_FITS=()
            BATCH_BAD=0
            BATCH_INCOMPLETE=0

            # Read each log once per batch. These are the same checks as the
            # v2dl3 branch of prepro_check_and_clean_files.sh.
            if ! perl - "${LOG_BATCH[@]}" > "$BATCH_RESULT" <<'PERL'
use strict;
use warnings;

for my $file (@ARGV) {
    my ($has_completion, $has_error, $has_segmentation) = (0, 0, 0);
    my $fh;
    if (!open($fh, '<', $file)) {
        print 'unreadable', "\0", $file, "\0";
        next;
    }

    while (my $line = <$fh>) {
        $has_completion = 1 if index($line, 'INFO:v2dl3: FITS output written to') >= 0;
        $has_error = 1 if lc($line) =~ /error/;
        $has_segmentation = 1 if $line =~ /segmentation/;
    }

    if (!close($fh)) {
        print 'unreadable', "\0", $file, "\0";
        next;
    }

    my $status = (!$has_completion || $has_error || $has_segmentation) ? 'bad' : 'good';
    print $status, "\0", $file, "\0";
}
PERL
            then
                echo "Error: DL3 log check failed for batch in $A" >&2
                exit 1
            fi

            while IFS= read -r -d '' STATUS && IFS= read -r -d '' LOG; do
                STEM=${LOG%.log}
                case "$STATUS" in
                    bad|unreadable)
                        move_products_to_error "$LOG"
                        BATCH_BAD=$((BATCH_BAD + 1))
                        ;;
                    good)
                        FITS="${STEM}.fits.gz"
                        if [[ ! -f "$FITS" ]]; then
                            echo "Skipping $LOG: matching FITS file is missing" >&2
                            BATCH_INCOMPLETE=$((BATCH_INCOMPLETE + 1))
                            continue
                        fi
                        clean_error_products "$LOG"
                        VALID_FITS+=("$FITS")
                        ;;
                    esac
            done < "$BATCH_RESULT"

            if ((${#VALID_FITS[@]} > 0)); then
                "${script_dir}/prepro_move_v2dl3_files.sh" "$A" "$DDIR" "${VALID_FITS[@]}"
            fi

            echo "Completed batch $((offset / BATCH_SIZE + 1)) in $A: " \
                "$((NLOG - offset < BATCH_SIZE ? NLOG - offset : BATCH_SIZE)) logs, " \
                "$BATCH_BAD moved to error, ${#VALID_FITS[@]} pairs moved, " \
                "$BATCH_INCOMPLETE incomplete"
        done

        # Report FITS products that never had a matching log. They are left in
        # place because an unpaired product must not be archived.
        for FITS in "$A"/*.fits.gz; do
            [[ -f "$FITS" ]] || continue
            LOG="${FITS%.fits.gz}.log"
            if [[ ! -f "$LOG" ]]; then
                echo "Unpaired FITS remains: $FITS (matching log is missing)" >&2
            fi
        done
    done
done
