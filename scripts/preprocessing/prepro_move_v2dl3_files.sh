#!/bin/bash
if [ $# -lt 1 ]; then
    echo "./move_v2dl3_files.sh <analysis type>"
echo "
./prepro_move_preprocessed_files.sh <analysis type>

    Move D3L data products and log files to archival directories.
    Note that analysis type needs to be taken into account in the directory naming.
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
    echo "${FTYPE}/$F*.fits.gz"
    mv -v ${FTYPE}/$F*.fits.gz $ODIR/$F/
    mv -v ${FTYPE}/$F*.log $ODIR/$F/
done
