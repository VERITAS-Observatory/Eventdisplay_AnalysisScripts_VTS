#!/bin/bash
# Check if runs read from a run list are processed already with
# evndisp or mscw files
#

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
./check_runs_on_disk.sh <runlist> <evndisp data type>

   evndisp data type can be evndisp, mscw
"
exit
fi

FF=$(cat ${1})
DTYPE=${2}

file_on_disk()
{
    ARCHIVEDIR="$VERITAS_DATA_DIR/processed_data_v490/${VERITAS_ANALYSIS_TYPE:0:2}/${DTYPE}/"
    TRUN="$1"
    if [[ ${TRUN} -lt 100000 ]]; then
        EDIR="${ARCHIVEDIR}/${TRUN:0:1}/"
    else
        EDIR="${ARCHIVEDIR}/${TRUN:0:2}/"
    fi
    if [[ ${DTYPE} == "mscw" ]]; then
        if [[ -e "${EDIR}/${TRUN}.mscw.root" ]]; then
            echo "TRUE"
            return
        fi
    else
        if [[ -e "${EDIR}/${TRUN}.root" ]]; then
            echo "TRUE"
            return
        fi
    fi
    echo "FALSE"
}

echo "Checking runs from ${1} for data type ${DTYPE}"

for F in ${FF}
do
    echo $F $(file_on_disk $F)
done
