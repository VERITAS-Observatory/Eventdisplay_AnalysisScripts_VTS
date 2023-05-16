#!/bin/bash
# generate a radial acceptance file

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
RLIST=RUNLIST
DDIR=INPUTDIR
CUTS=CUTSFILE
ODIR=OUTPUTDIR
OFILE=OUTPUTFILE
TTA=TELTOANA

# create radial acceptance
rm -f "$ODIR/$OFILE.log"
$EVNDISPSYS/bin/makeRadialAcceptance -l $RLIST -c $CUTS -d $DDIR -o $ODIR/$OFILE.root -t $TTA &> $ODIR/$OFILE.log

$EVNDISPSYS/bin/logFile radAccLOG "$ODIR/$OFILE.root" "$ODIR/$OFILE.log"

exit
