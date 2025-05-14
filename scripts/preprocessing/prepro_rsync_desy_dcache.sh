#!/bin/bash
# Sync pre-processed Eventdisplay data with DESY dCache


BDIR="/pnfs/ifh.de/acs/veritas/diskonly/processed_data"
IDIR="$VERITAS_DATA_DIR/shared/"

# DBTEXT
echo "Syncing DBTEXT"
rsync -av $IDIR/DBTEXT/* "$BDIR/DBTEXT/"

# DBFITS
echo "Syncing DBFITS"
rsync -av $IDIR/DBFITS/* "$BDIR/DBFITS/"

# v491.0
echo "Syncing DL3 v491.0"
rsync -av $IDIR/processed_data_v491.0/AP/dl3*.tar.gz "$BDIR/v491.0/"
echo "Syncing mscw v491.0"
rsync -av $IDIR/processed_data_v491.0/AP/mscw/* "$BDIR/v491.0/AP/"

# v490.7
echo "Syncing evndisp v490.7 AP"
rsync -av $IDIR/processed_data_v490.7/AP/evndisp/ "$BDIR/v490.7/AP/evndisp/"
echo "Syncing evndisp v490.7 NN"
rsync -av $IDIR/processed_data_v490.7/NN/evndisp/ "$BDIR/v490.7/NN/evndisp/"
echo "Syncing DL3 v490.7 AP"
rsync -av $IDIR/processed_data_v490.7/AP/dl3*.tar.gz "$BDIR/v490.7/DL3/"
echo "Syncing DL3 v490.7 NN"
rsync -av $IDIR/processed_data_v490.7/NN/dl3*.tar.gz "$BDIR/v490.7/DL3/"
