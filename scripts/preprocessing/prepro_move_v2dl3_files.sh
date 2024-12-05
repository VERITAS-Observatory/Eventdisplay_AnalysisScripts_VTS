#!/bin/bash
if [ $# -lt 2 ]; then
    echo "./move_v2dl3_files.sh <source dl3 directory> <target directory>"
echo "
./prepro_move_preprocessed_files.sh <source dl3 directory> <target directory>

    Move D3L data products and log files to archival directories.
    Note that analysis type needs to be taken into account in the directory naming.
"
    exit
fi

FTYPE="$1"
DDIR="$2"

ANATYPE="AP"
ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
VERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFMINORVERSION)

ODIR="$VERITAS_DATA_DIR/shared/processed_data_${VERSION}/${ANATYPE}/"
echo "ODIR $ODIR"

for F in 10 9 8 7 6 5 4 3; do
   mkdir -p $ODIR/$DDIR/$F
done

for F in 10 9 8 7 6 5 4 3; do
    mv -v ${FTYPE}/${F}/*.fits.gz $ODIR/$DDIR/${F}/
    mv -v ${FTYPE}/${F}/*.log $ODIR/$DDIR/${F}/
done
