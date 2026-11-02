#!/bin/bash
# shellcheck disable=SC2086
# EVNDISPSYS may include an apptainer exec prefix and must split into command words.
# generate a radial acceptance file

# shellcheck source=/dev/null
# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

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
