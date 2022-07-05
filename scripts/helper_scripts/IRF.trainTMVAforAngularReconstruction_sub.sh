#!/bin/bash
# script to train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
INDIR=EVNDISPFILE
ODIR=OUTPUTDIR
ONAME=BDTFILE
RECID="0"
TELTYPE="0"

rm -f "$ODIR/$ONAME*"

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

ls -1 "$INDIR/*[0-9].root" | sort -R | head -n 1 > $ODIR/${ONAME}.list

for disp in BDTDisp BDTDispError
do
    "$EVNDISPSYS"/bin/trainTMVAforAngularReconstruction \
        $ODIR/${ONAME}.list \
        "$TRAINTESTFRACTION" \
        "$RECID" \
        "$TELTYPE" \
        "$disp" > "$ODIR/$ONAME-$disp.log"
done
