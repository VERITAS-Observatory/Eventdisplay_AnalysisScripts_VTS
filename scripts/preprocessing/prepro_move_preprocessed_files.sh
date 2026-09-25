#!/bin/bash
if [ $# -lt 1 ]; then
echo "
./prepro_move_preprocessed_files.sh <analysis type> [backup suffix]

    Move data products and log files to archival directories.
    If a backup suffix is given, existing destination files are backed up
    in the same directory before being replaced (e.g. '.bak').
"
    exit
fi

FTYPE="$1"
BACKUP_SUFFIX="${2:-}"

RSYNC_BACKUP_OPTIONS=()
if [[ -n "$BACKUP_SUFFIX" ]]; then
    RSYNC_BACKUP_OPTIONS=(--backup "--suffix=$BACKUP_SUFFIX")
fi

ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
VERSION=$(cat "$VERITAS_EVNDISP_AUX_DIR"/IRFMINORVERSION)

ODIR="$VERITAS_DATA_DIR/shared/processed_data_${VERSION}/${ANATYPE}/${FTYPE}"

if [[ $FTYPE == "xgb" ]]; then
    ODIR="$VERITAS_DATA_DIR/shared/processed_data_${VERSION}/${ANATYPE}/mscw"
fi

for F in 11 10 9 8 7 6 5 4 3; do
    OFDIR="$ODIR/$F"
    echo "Syncing $OFDIR with ${FTYPE}"
    mkdir -p "$OFDIR"
    ROOT_MATCH=$(find "$FTYPE" -maxdepth 1 -type f -name "${F}*.root" -print -quit 2>/dev/null)
    if [[ -n "$ROOT_MATCH" ]]; then
        rsync -a --whole-file --remove-source-files \
            --human-readable --info=progress2 \
            "${RSYNC_BACKUP_OPTIONS[@]}" \
            --include="${F}*.root" \
            --include="${F}*.log" \
            --exclude='*' \
            "$FTYPE/" "$OFDIR/"
    fi
done
