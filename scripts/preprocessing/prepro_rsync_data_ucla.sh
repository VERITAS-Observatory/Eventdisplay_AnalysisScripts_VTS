#!/bin/bash
# Sync pre-processed Eventdisplay data with UCLA
# This includes Eventdisplay data products
# data products

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
./prepro_rsync_data_ucla.sh <backup eversion (e.g., '.v3.4')

Run this script at DESY from '/lustre/fs24/group/veritas/shared/'

"
exit
fi

if [[ ! -n "${VTS_UCLA_USER}" ]]; then
    echo "Environmental variable VTS_UCLA_USER not set"
    exit
fi

USER="${VTS_UCLA_USER}"
VERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFMINORVERSION)
VERSION="v491.0"
VERSION="v490.7"
BACKUP="$1"
ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
ANATYPE="AP"
ANATYPE="NN"

echo "USER: $USER VERSION $VERSION ANATYPE $ANATYPE BACKUP $BACKUP"
if [[ $VERSION = "v490.7"* ]]; then
    SYNC_EVNDISP=TRUE
    SYNC_MSCW=TRUE
    # SYNC_DL3TAR=TRUE
    SYNC_DL3=TRUE
else
    SYNC_EVNDISP=FALSE
    SYNC_MSCW=FALSE
    SYNC_DL3TAR=TRUE
    SYNC_DL3=FALSE
fi

if [[ $SYNC_DL3TAR == "TRUE" ]]; then
    echo "Syncing DL3 tar ball"
    rsync -avz -e ssh \
         ./processed_data_${VERSION}/$ANATYPE/*.tar.gz \
         ${USER}:/home/maierg/processed_Eventdisplay/${VERSION}/$ANATYPE/
fi


if [[ $SYNC_DL3 == "TRUE" ]]; then
    echo "Syncing DL3 files"
    DLDIRS=$(find ./processed_data_${VERSION}/$ANATYPE/ -type d -name 'dl3_*')
    for DL in $DLDIRS; do
         echo $DL
         DL3=$(basename $DL)
         echo "SYNC with ${USER}:/home/maierg/processed_Eventdisplay/${VERSION}/$ANATYPE/$DL3/"

         rsync -avz -e ssh \
              --backup --suffix="$BACKUP" \
              $DL/* \
             ${USER}:/home/maierg/processed_Eventdisplay/${VERSION}/$ANATYPE/$DL3/
    done
fi

if [[ $SYNC_MSCW == "TRUE" ]]; then
    echo "Syncing mscw"
    rsync -avz -e ssh \
          --backup --suffix="$BACKUP" \
         ./processed_data_${VERSION}/$ANATYPE/mscw/* \
         ${USER}:/home/maierg/processed_Eventdisplay/${VERSION}/$ANATYPE/mscw/
fi


if [[ $SYNC_EVNDISP == "TRUE" ]]; then
    echo "Syncing evndisp"
    rsync -avz -e ssh \
         --backup --suffix="$BACKUP" \
        ./processed_data_${VERSION}/$ANATYPE/evndisp/* \
        ${USER}:/home/maierg/processed_Eventdisplay/${VERSION}/$ANATYPE/evndisp/
fi
