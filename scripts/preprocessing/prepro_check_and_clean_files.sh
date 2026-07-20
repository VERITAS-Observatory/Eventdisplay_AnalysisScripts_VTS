#!/bin/bash
if [ $# -lt 1 ]; then
echo "
./prepro_check_and_clean_files.sh <analysis type>

    Check log files for a given analysis type for errors and segmentation fault.
    Move error files into a error directory.
    Recover files from error directory for files successfully processed.

    grep -i error ./mscw/*.log | grep -v BDTDispError | grep -v "BDT disp" | grep -v weighting
"
    exit
fi

FTYPE="$1"
echo "Searching for errors for data type $FTYPE"

# simplified search for mscw
if [[ $FTYPE == "mscw" ]]; then
    grep -i error ./mscw/*.log | grep -Ev 'BDTDispError|BDT disp|weighting'
    echo "Finalized error search for mscw"
    exit
fi

# find all files with errors in the log file
move_list()
{
    mkdir -p "${FTYPE}"/"${1}"
    for F in ${2}; do
        mv -f "${FTYPE}/$(basename "$F" .log)."* "${FTYPE}/${1}/"
    done
}

# for xgb products: require the eventdisplay-ml completion message
if [[ $FTYPE == "xgb" ]]; then
    xgb_bad_logs=""
    shopt -s nullglob
    for F in "$FTYPE"/*.log; do
        if ! grep -qF "INFO:eventdisplay_ml.models:Total processed events written" "$F"; then
            xgb_bad_logs+="$F "$'\n'
        fi
    done
    shopt -u nullglob

    if [[ -n $xgb_bad_logs ]]; then
        file_count=$(echo "$xgb_bad_logs" | wc -w)
        echo "FOUND $file_count xgb log files without the eventdisplay-ml completion message"
        move_list error "$xgb_bad_logs"
    fi
fi

# for anasum products: require VERITAS_ANALYSIS_TYPE in the last log line
if [[ $FTYPE == anasum* ]]; then
    anasum_bad_logs=""
    shopt -s nullglob
    for F in "$FTYPE"/*.log; do
        if ! tail -n 1 "$F" | grep -q "VERITAS_ANALYSIS_TYPE"; then
            anasum_bad_logs+="$F "$'\n'
        fi
    done
    shopt -u nullglob

    if [[ -n $anasum_bad_logs ]]; then
        file_count=$(echo "$anasum_bad_logs" | wc -w)
        echo "FOUND $file_count anasum log files without VERITAS_ANALYSIS_TYPE in the last line"
        move_list error "$anasum_bad_logs"
    fi
fi

# find all runs with errors and move them
FLIST=$(grep -irl "error" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with errors"
    fi
    move_list error "$FLIST"
fi
# find all runs with segmentation faults
FLIST=$(grep -rl "segmentation" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with segmentation faults"
    fi
    move_list error "$FLIST"
fi
# find all runs without errors and remove them from error directory
FLIST=$(grep -iL "error" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files without errors - cleaning error directory"
        for F in $FLIST; do
            rm -f "${FTYPE}/error/$(basename "$F" .log)."*
        done
    fi
fi

echo "Aux data (and NOTFOUND)"
NAUX=$(find "$FTYPE" -maxdepth 1 -name "*.NOTFOUND" 2>/dev/null | wc -l)
if [[ $NAUX -gt 0 ]]; then
    mkdir -p "$FTYPE"/aux
    mv -f "$FTYPE"/*.NOTFOUND "$FTYPE"/aux/
fi
echo "Remove list file (*.list, *.runlist)"
rm -f "$FTYPE"/*.list
rm -f "$FTYPE"/*.runlist
