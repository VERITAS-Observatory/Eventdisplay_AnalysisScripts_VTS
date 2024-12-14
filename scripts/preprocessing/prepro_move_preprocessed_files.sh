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

for F in 11 10 9 8 7 6 5 4 3; do
    OFDIR="$ODIR/$F"
    echo "Syncing $OFDIR with ${FTYPE}"
    mkdir -p "$OFDIR"
    rsync -av --remove-source-files ${FTYPE}/${F}*.root $OFDIR/
    rsync -av --remove-source-files ${FTYPE}/${F}*.log $OFDIR/
done
