#!/bin/bash
set -euo pipefail

BDIR="/pnfs/ifh.de/acs/veritas/diskonly/processed_data"
IDIR="$VERITAS_DATA_DIR/shared/"
FLAGS=(-av --inplace)

process_sync() {
    local SRC="$1"
    local DST="$2"
    local FILTER="${3:-}"

    echo "Scanning: $SRC -> $DST"
    rsync -av --dry-run --itemize-changes \
        ${FILTER:+--include="*/" --include="$FILTER" --exclude="*"} \
        "$SRC/" "$DST/" | awk '/^>f/ {print $2}' | while IFS= read -r f; do
        # skip any backup files in source
        case "$f" in
            *.back) continue ;;  # ignore backup files
        esac

        dst_file="$DST/$f"
        mkdir -p "$(dirname "$dst_file")"

        # remove any previous backup (only one)
        [ -f "${dst_file}.back" ] && rm -f "${dst_file}.back"

        # move current file to .back if it exists
        [ -f "$dst_file" ] && mv "$dst_file" "${dst_file}.back"
    done

    echo "Syncing: $SRC -> $DST"
    rsync "${FLAGS[@]}" --size-only --dry-run \
        ${FILTER:+--include="*/" --include="$FILTER" --exclude="*"} \
        "$SRC" "$DST"
}

# ---- Jobs ----

echo "Syncing evndisp v490.7 AP"
process_sync "$IDIR/processed_data_v490.7/AP/evndisp/" "$BDIR/v490.7/AP/evndisp/"

echo "Syncing evndisp v490.7 NN"
process_sync "$IDIR/processed_data_v490.7/NN/evndisp/" "$BDIR/v490.7/NN/evndisp/"

echo "Syncing DL3 v490.7 AP"
process_sync "$IDIR/processed_data_v490.7/AP/" "$BDIR/v490.7/DL3/" "dl3*.tar.gz"

echo "Syncing DL3 v490.7 NN"
process_sync "$IDIR/processed_data_v490.7/NN/" "$BDIR/v490.7/DL3/" "dl3*.tar.gz"

echo "Syncing DL3 v491.0"
process_sync "$IDIR/processed_data_v491.0/AP/" "$BDIR/v491.0/" "dl3*.tar.gz"

echo "Syncing mscw v491.0"
process_sync "$IDIR/processed_data_v491.0/AP/mscw/" "$BDIR/v491.0/mscw/"
