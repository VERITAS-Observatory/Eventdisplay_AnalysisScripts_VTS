#!/bin/bash
set -euo pipefail

BDIR="/pnfs/ifh.de/acs/veritas/diskonly/processed_data"
: "${VERITAS_DATA_DIR:?VERITAS_DATA_DIR must be set and non-empty}"
IDIR="${VERITAS_DATA_DIR%/}/shared"

process_sync() {
    local SRC="${1%/}"
    local DST="${2%/}"
    local FILTER="${3:-}"
    # Keep one previous destination version when rsync replaces a file.
    # Exclude source backups before applying any product include rules.
    local -a OPTS=(
        -av --prune-empty-dirs
        --backup --suffix=.back
        '--exclude=*.back'
    )

    if [[ -n "$FILTER" ]]; then
        OPTS+=('--include=*/' "--include=$FILTER" '--exclude=*')
    fi

    if [[ ! -d "$SRC" ]]; then
        echo "Source directory does not exist: $SRC" >&2
        return 1
    fi

    echo "Syncing: $SRC -> $DST"
    mkdir -p -- "$DST" || return
    rsync "${OPTS[@]}" -- "$SRC/" "$DST/"
}

# ---- Jobs ----

# DBFITS
echo "Syncing DBFITS"
process_sync "$IDIR/DBFITS/" "$BDIR/DBFITS/"

# DBTEXT
echo "Syncing DBTEXT"
process_sync "$IDIR/DBTEXT/" "$BDIR/DBTEXT/"

# v490.7
echo "Syncing evndisp v490.7 AP"
process_sync "$IDIR/processed_data_v490.7/AP/evndisp/" "$BDIR/v490.7/AP/evndisp/"
echo "Syncing evndisp v490.7 NN"
process_sync "$IDIR/processed_data_v490.7/NN/evndisp/" "$BDIR/v490.7/NN/evndisp/"
echo "Syncing DL3 v490.7 AP"
process_sync "$IDIR/processed_data_v490.7/AP/" "$BDIR/v490.7/DL3/" "dl3*.tar.gz"
echo "Syncing DL3 v490.7 NN"
process_sync "$IDIR/processed_data_v490.7/NN/" "$BDIR/v490.7/DL3/" "dl3*.tar.gz"

# v491.0
echo "Syncing DL3 v491.0"
process_sync "$IDIR/processed_data_v491.0/AP/" "$BDIR/v491.0/DL3/" "dl3*.tar.gz"
echo "Syncing mscw v491.0"
process_sync "$IDIR/processed_data_v491.0/AP/mscw/" "$BDIR/v491.0/AP/mscw/"
