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
    local LOG
    local GREP_STATUS
    local -a FILES_11=()
    local -a FILES_10=()
    local -a FILES_9=()
    local -a FILES_8=()
    local -a FILES_7=()
    local -a FILES_6=()
    local -a FILES_5=()
    local -a FILES_4=()
    local -a FILES_3=()

    for FITS in "$@"; do
        [[ -f "$FITS" ]] || continue
        NAME=${FITS##*/}
        for F in 11 10 9 8 7 6 5 4 3; do
            if [[ $NAME == "${F}"*.fits.gz ]]; then
                LOG="${FITS%.fits.gz}.log"
                if [[ ! -f "$LOG" ]]; then
                    echo "Skipping $FITS: matching log file is missing" >&2
                    break
                fi

                if grep -qi -- "Error" "$LOG"; then
                    echo "Skipping $FITS and $LOG: log contains Error" >&2
                    break
                else
                    GREP_STATUS=$?
                    if [[ $GREP_STATUS -ne 1 ]]; then
                        echo "Skipping $FITS and $LOG: unable to inspect log file" >&2
                        break
                    fi
                fi

                # Collect complete pairs first so rsync can transfer one
                # batch per destination instead of one batch per product.
                case "$F" in
                    11) FILES_11+=("$FITS" "$LOG") ;;
                    10) FILES_10+=("$FITS" "$LOG") ;;
                    9)  FILES_9+=("$FITS" "$LOG") ;;
                    8)  FILES_8+=("$FITS" "$LOG") ;;
                    7)  FILES_7+=("$FITS" "$LOG") ;;
                    6)  FILES_6+=("$FITS" "$LOG") ;;
                    5)  FILES_5+=("$FITS" "$LOG") ;;
                    4)  FILES_4+=("$FITS" "$LOG") ;;
                    3)  FILES_3+=("$FITS" "$LOG") ;;
                esac
                break
            fi
        done
    done

    for F in 11 10 9 8 7 6 5 4 3; do
        local -n FILES="FILES_${F}"
        ((${#FILES[@]} > 0)) || continue
        OFDIR="$ODIR/$DDIR/$F"
        mkdir -p "$OFDIR"
        echo "Syncing $OFDIR with ${FTYPE} (${#FILES[@]} files)"
        rsync -av --remove-source-files "${FILES[@]}" "$OFDIR"/
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
