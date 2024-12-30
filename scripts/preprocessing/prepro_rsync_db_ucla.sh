#!/bin/bash
# Sync pre-processed DBFITS and DBTEXT files with UCLA

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
./prepro_rsync_db_ucla.sh <backup eversion (e.g., '.v3.4')

Run this script at DESY from '/lustre/fs24/group/veritas/shared/'
"
exit
fi

if [[ ! -n "${VTS_UCLA_USER}" ]]; then
    echo "Environmental variable VTS_UCLA_USER not set"
    exit
fi

USER="${VTS_UCLA_USER}"
BACKUP="$1"

echo "USER: $USER BACKUP $BACKUP"

rsync -avz -e ssh \
      --backup --suffix="$BACKUP" \
     ./DBFITS \
     ${USER}:/home/maierg/processed_Eventdisplay/

rsync -avz -e ssh \
      --backup --suffix="$BACKUP" \
     ./DBTEXT \
     ${USER}:/home/maierg/processed_Eventdisplay/
