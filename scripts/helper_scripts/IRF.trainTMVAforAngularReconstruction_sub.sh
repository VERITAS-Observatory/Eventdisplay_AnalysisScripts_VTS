#!/bin/bash
# script to train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
LLIST=EVNLIST
ODIR=OUTPUTDIR
ONAME=BDTFILE
RECID="0"
TELTYPE="0"

rm -f "$ODIR/$ONAME*"

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

# temporary directory
if [[ -n "$TMPDIR" ]]; then 
    DDIR="$TMPDIR/dispBDT/"
else
    DDIR="/tmp/dispBDT/"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

for disp in BDTDisp BDTDispError
do
    "$EVNDISPSYS"/bin/trainTMVAforAngularReconstruction \
        ${ODIR}/${ONAME}.list \
        ${DDIR} \
        "$TRAINTESTFRACTION" \
        "$RECID" \
        "$TELTYPE" \
        "$disp" > "$ODIR/$ONAME-$disp.log"

    cp -f ${DDIR}/${disp}_*.root ${ODIR}/
    cp -f ${DDIR}/${disp}_*.xml ${ODIR}/
done
