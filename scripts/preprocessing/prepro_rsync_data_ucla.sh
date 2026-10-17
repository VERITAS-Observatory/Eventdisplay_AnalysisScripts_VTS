#!/usr/bin/env bash
# Sync pre-processed Eventdisplay data with UCLA.
# This includes Eventdisplay data products.

set -euo pipefail
shopt -s nullglob

usage() {
    cat <<'EOF'
Usage: ./prepro_rsync_data_ucla.sh <backup suffix> <Eventdisplay version> <analysis type>

Run this script at DESY from '/lustre/fs24/group/veritas/shared/'.
Example: ./prepro_rsync_data_ucla.sh .v3.4 v490.7 AP
EOF
}

if (( $# == 1 )) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if (( $# != 3 )); then
    usage
    exit 2
fi

if [[ -z "${VTS_UCLA_USER:-}" ]]; then
    echo "Environmental variable VTS_UCLA_USER not set" >&2
    exit 1
fi

BACKUP=$1
VERSION=$2
ANATYPE=$3
UCLA_USER=$VTS_UCLA_USER
UCLA_DIR="/home/maierg/processed_Eventdisplay/${VERSION}/${ANATYPE}"
SOURCE_DIR="./processed_data_${VERSION}/${ANATYPE}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

echo "USER: $UCLA_USER VERSION $VERSION ANATYPE $ANATYPE BACKUP $BACKUP"

SYNC_EVNDISP=FALSE
SYNC_MSCW=FALSE
SYNC_DL3TAR=FALSE
SYNC_DL3=FALSE

if [[ $VERSION == v490.7* ]]; then
    if [[ $ANATYPE == AP ]]; then
        SYNC_EVNDISP=TRUE
        SYNC_MSCW=TRUE
        SYNC_DL3TAR=TRUE
        SYNC_DL3=TRUE
    else
        SYNC_DL3TAR=TRUE
    fi
else
    SYNC_MSCW=TRUE
    SYNC_DL3=TRUE
fi

if [[ $SYNC_DL3TAR == TRUE ]]; then
    echo "Syncing DL3 tar balls"
    TAR_FILES=("$SOURCE_DIR"/*.tar.gz)
    if (( ${#TAR_FILES[@]} )); then
        rsync -avz -e ssh -- "${TAR_FILES[@]}" "${UCLA_USER}:${UCLA_DIR}/"
    else
        echo "No DL3 tar balls found in $SOURCE_DIR"
    fi
fi

if [[ $SYNC_DL3 == TRUE ]]; then
    echo "Syncing DL3 files"
    DL_DIRS=()
    while IFS= read -r -d '' dir; do
        DL_DIRS+=("$dir")
    done < <(find "$SOURCE_DIR" -type d -name 'dl3_*' -print0)

    for dl_dir in "${DL_DIRS[@]}"; do
        dl_name=${dl_dir##*/}
        echo "Syncing $dl_dir to ${UCLA_USER}:${UCLA_DIR}/${dl_name}/"
        rsync -avz -e ssh --backup --suffix="$BACKUP" -- \
            "$dl_dir/" "${UCLA_USER}:${UCLA_DIR}/${dl_name}/"
    done
fi

if [[ $SYNC_MSCW == TRUE ]]; then
    echo "Syncing mscw"
    if [[ ! -d "$SOURCE_DIR/mscw" ]]; then
        echo "Source directory does not exist: $SOURCE_DIR/mscw" >&2
        exit 1
    fi
    rsync -avz -e ssh --backup --suffix="$BACKUP" -- \
        "$SOURCE_DIR/mscw/" "${UCLA_USER}:${UCLA_DIR}/mscw/"
fi

if [[ $SYNC_EVNDISP == TRUE ]]; then
    echo "Syncing evndisp"
    if [[ ! -d "$SOURCE_DIR/evndisp" ]]; then
        echo "Source directory does not exist: $SOURCE_DIR/evndisp" >&2
        exit 1
    fi
    rsync -avz -e ssh --backup --suffix="$BACKUP" -- \
        "$SOURCE_DIR/evndisp/" "${UCLA_USER}:${UCLA_DIR}/evndisp/"
fi
