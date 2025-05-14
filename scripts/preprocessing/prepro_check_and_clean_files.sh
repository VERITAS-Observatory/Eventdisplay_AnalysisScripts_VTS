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

# find all files with errors in the log file

move_list()
{
    mkdir -p "${FTYPE}"/"${1}"
    for F in ${2}; do
        mv -f "${FTYPE}"/$(basename $F .log).* "${FTYPE}"/"${1}"/
    done
}

echo "Searching for errors for data type $FTYPE"

# find all runs with errors and move them
FLIST=$(grep -irl "error" $FTYPE/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with errors"
    fi
    move_list error "$FLIST"
fi
# find all runs with segmentation faults
FLIST=$(grep -rl "segmentation" $FTYPE/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with segmentation faults"
    fi
    move_list error "$FLIST"
fi
# find all runs without errors and remove them from error directory
FLIST=$(grep -iL "error" $FTYPE/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files without errors - cleaning error directory"
        for F in $FLIST; do
            rm -f ${FTYPE}/error/$(basename $F .log).*
        done
    fi
fi

echo "Aux data (and NOTFOUND)"
NAUX=$(ls -1 "$FTYPE"/*.NOTFOUND 2>/dev/null | wc -l)
if [[ $NAUX -gt 0 ]]; then
    mkdir -p "$FTYPE"/aux
    mv -f "$FTYPE"/*.NOTFOUND "$FTYPE"/aux/
fi
echo "Remove list file (*.list, *.runlist)"
rm -f "$FTYPE"/*.list
rm -f "$FTYPE"/*.runlist
