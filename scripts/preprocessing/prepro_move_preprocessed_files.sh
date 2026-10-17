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

mapfile -t PREFIXES < <(find "$FTYPE" -maxdepth 1 -type f -name '*.root' -printf '%f\n' |
    awk -F. '$1 ~ /^[0-9]+$/ && length($1) >= 5 {print substr($1,1,($1 < 100000 ? 1 : 2))}' | sort -nu)
for F in "${PREFIXES[@]}"; do
    OFDIR="$ODIR/$F"
    echo "Syncing $OFDIR with ${FTYPE}"
    mkdir -p "$OFDIR"
    mapfile -t FILES < <(find "$FTYPE" -maxdepth 1 -type f \( -name '*.root' -o -name '*.log' \) -printf '%f\n' |
        awk -F. -v prefix="$F" '$1 ~ /^[0-9]+$/ && substr($1,1,($1 < 100000 ? 1 : 2)) == prefix')
    ((${#FILES[@]})) || continue
    printf '%s\n' "${FILES[@]}" | rsync -a --whole-file --remove-source-files \
        --human-readable --info=progress2 "${RSYNC_BACKUP_OPTIONS[@]}" \
        --files-from=- "$FTYPE/" "$OFDIR/" || exit 1

done
