#!/bin/bash
# script to combine anasum runs
#
# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
RUNLIST=RRUNLIST
DDIR=DDDIR
RUNP=RRUNP
OUTFILE=OOUTFILE

mkdir -p ${DDIR}
rm -f ${DDIR}/$OUTFILE.log

$EVNDISPSYS/bin/anasum \
    -i 1 \
    -l ${RUNLIST} \
    -d ${DDIR} \
    -f ${RUNP} \
    -o ${DDIR}/${OUTFILE}.root 2>&1 | tee ${DDIR}/${OUTFILE}.log

$EVNDISPSYS/bin/logFile \
    anasumLog \
    ${DDIR}/${OUTFILE}.root \
    ${DDIR}/${OUTFILE}.log

exit
