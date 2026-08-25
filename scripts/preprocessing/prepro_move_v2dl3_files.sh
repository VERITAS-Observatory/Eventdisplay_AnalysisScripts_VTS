#!/bin/bash
if [ $# -lt 2 ]; then
echo "
./prepro_move_v2dl3_files.sh <source dl3 directory> <target directory> [fits files ...]

    Move D3L data products and log files to archival directories.
    Note that analysis type needs to be taken into account in the directory naming.
"
    exit
fi

FTYPE="$1"
DDIR="$2"

ANATYPE="AP"
ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
VERSION=$(cat "$VERITAS_EVNDISP_AUX_DIR"/IRFMINORVERSION)

ODIR="$VERITAS_DATA_DIR/shared/processed_data_${VERSION}/${ANATYPE}/"

shopt -s nullglob

move_pair()
{
    local FITS=$1
    local OFDIR=$2
    local LOG="${FITS%.fits.gz}.log"
    local GREP_STATUS

    [[ -f "$FITS" ]] || return 0
    if [[ ! -f "$LOG" ]]; then
        echo "Skipping $FITS: matching log file is missing" >&2
        return 0
    fi

    if grep -qi -- "Error" "$LOG"; then
        echo "Skipping $FITS and $LOG: log contains Error" >&2
        return 0
    else
        GREP_STATUS=$?
        if [[ $GREP_STATUS -ne 1 ]]; then
            echo "Skipping $FITS and $LOG: unable to inspect log file" >&2
            return 0
        fi
    fi

    mkdir -p "$OFDIR"
    rsync -av --remove-source-files "$FITS" "$LOG" "$OFDIR"/
}

move_specific_files()
{
    local FITS
    local NAME
    local F

    for FITS in "$@"; do
        [[ -f "$FITS" ]] || continue
        NAME=${FITS##*/}
        for F in 11 10 9 8 7 6 5 4 3; do
            if [[ $NAME == "${F}"*.fits.gz ]]; then
                echo "Syncing $ODIR/$DDIR/$F with ${FTYPE}"
                move_pair "$FITS" "$ODIR/$DDIR/$F"
                break
            fi
        done
    done
}

if [[ $# -gt 2 ]]; then
    # Optional file arguments are used by the batch wrapper so that only the
    # validated files from the current batch are moved.
    move_specific_files "${@:3}"
else
    for F in 11 10 9 8 7 6 5 4 3; do
        OFDIR="$ODIR/$DDIR/$F"
        echo "Syncing $OFDIR with ${FTYPE}"
        for FITS in "$FTYPE"/"${F}"*.fits.gz; do
            [[ -f "$FITS" ]] || continue
            move_pair "$FITS" "$OFDIR"
        done
    done
fi
