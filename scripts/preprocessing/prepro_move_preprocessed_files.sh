#!/bin/bash
if [ $# -lt 1 ]; then
echo "
./prepro_move_preprocessed_files.sh <analysis type>

    Move data products and log files to archival directories.
"
    exit
fi

FTYPE="$1"

ANATYPE="AP"
ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
VERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFMINORVERSION)

ODIR="$VERITAS_DATA_DIR/shared/processed_data_${VERSION}/${ANATYPE}/${FTYPE}"

for F in 10 9 8 7 6 5 4 3; do
    mkdir -p $ODIR/$F/
done

for F in 10 9 8 7 6 5 4 3; do
    echo $ODIR/$F/
    echo "${FTYPE}/$F*.root"
    mv -v ${FTYPE}/$F*.root $ODIR/$F/
    mv -v ${FTYPE}/$F*.log $ODIR/$F/
done
