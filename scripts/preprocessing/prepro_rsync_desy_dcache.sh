#!/bin/bash
# Sync pre-processed Eventdisplay data with DESY dCache


BDIR="/pnfs/ifh.de/acs/veritas/diskonly/processed_data"
IDIR="$VERITAS_DATA_DIR/shared/"

# v491.0
rsync -av $IDIR/processed_data_v491.0/AP/dl3*.tar.gz "$BDIR/v491.0/"

# v490.7
rsync -av $IDIR/processed_data_v490.7/AP/evndisp/ "$BDIR/v490.7/AP/evndisp/"
rsync -av $IDIR/processed_data_v490.7/NN/evndisp/ "$BDIR/v490.7/NN/evndisp/"
rsync -av $IDIR/processed_data_v490.7/AP/dl3*.tar.gz "$BDIR/v490.7/DL3/"
rsync -av $IDIR/processed_data_v490.7/NN/dl3*.tar.gz "$BDIR/v490.7/DL3/"

# DBFITS
rsync -av $IDIR/DBFITS/* "$BDIR/DBFITS/"

# DBTEXT
rsync -av $IDIR/DBTEXT/* "$BDIR/DBTEXT/"
