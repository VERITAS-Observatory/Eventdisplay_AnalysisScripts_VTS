#!/bin/bash
# script to analyse laser files 

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
RUN=RUNFILE
TELTOANA=TELTOANACOMB
LOGDIR=LOGDIRECTORY
CDIR=CURRENTDIR
echo $RUN

# run eventdisplay
rm -f $LOGDIR/$RUN.laser.log
${CDIR}/SPANALYSIS.evndisp_laser_run.sh $RUN $TELTOANA &> $LOGDIR/$RUN.laser.log

exit
