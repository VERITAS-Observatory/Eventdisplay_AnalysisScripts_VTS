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

run_prefix()
{
    local name=${1##*/} run
    run=${name%%.*}
    [[ $run =~ ^[0-9]{5,}$ ]] || return 1
    echo "${run:0:${#run}-4}"
}

move_specific_files()
{
    local FITS LOG F OFDIR
    local -A PREFIX_SET=()
    for FITS in "$@"; do
        [[ -f $FITS ]] || continue
        F=$(run_prefix "$FITS") || { echo "Invalid run filename: $FITS" >&2; return 1; }
        LOG="${FITS%.fits.gz}.log"
        [[ -f $LOG ]] || { echo "Missing log: $LOG" >&2; return 1; }
        if grep -qi -- "Error" "$LOG"; then
            echo "Conversion error in $LOG" >&2
            return 1
        else
            [[ $? == 1 ]] || return 1
        fi
        if [[ -z ${PREFIX_SET[$F]+set} ]]; then
            local -a "FILES_${F}=()"
            PREFIX_SET[$F]=1
        fi
        local -n FILES="FILES_${F}"
        FILES+=("$FITS" "$LOG")
    done
    for F in "${!PREFIX_SET[@]}"; do
        local -n FILES="FILES_${F}"
        OFDIR="$ODIR/$DDIR/$F"
        mkdir -p "$OFDIR" || return 1
        rsync -av --remove-source-files "${FILES[@]}" "$OFDIR/" || return 1
    done
}

if [[ $# -gt 2 ]]; then
    # Optional file arguments are used by the batch wrapper so that only the
    # validated files from the current batch are moved.
    move_specific_files "${@:3}"
else
    for FITS in "$FTYPE"/*.fits.gz; do
        [[ -f $FITS ]] || continue
        F=$(run_prefix "$FITS") || exit 1
        OFDIR="$ODIR/$DDIR/$F"
        move_pair "$FITS" "$OFDIR" || exit 1
    done
fi
