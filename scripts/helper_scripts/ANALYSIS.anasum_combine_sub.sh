#!/bin/bash
# script to combine anasum runs
#
# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source $EVNDISPSYS/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
RUNLIST=RRUNLIST
DDIR=DDDIR
RUNP=RRUNP
OUTFILE=OOUTFILE

mkdir -p ${DDIR}
rm -f ${DDIR}/$OUTFILE.log

# determine if this is a short or long run list
# (use VERSION string to identify long run list)
NV=$(grep -c "VERSION" ${RUNLIST})
if [ $NV -eq 0 ]; then
    RUNLISTSTRING="-k ${RUNLIST}"
else
    RUNLISTSTRING="-l ${RUNLIST}"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/anasum
    fi
}

$EVNDISPSYS/bin/anasum \
    -i 1 \
    ${RUNLISTSTRING} \
    -d ${DDIR} \
    -f ${RUNP} \
    -o ${DDIR}/${OUTFILE}.root 2>&1 | tee ${DDIR}/${OUTFILE}.log

# for Crab runs: print sensitivity estimate
RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${DDIR}/${OUTFILE}.root -runinfo)
TMPTARGET=$(echo $RUNINFO | cut -d\  -f7- )
if [[ ${TMPTARGET} == "Crab" ]]; then
    root -l -q -b "$EVNDISPSYS/macros/VTS/print_sensitivity.C(\"${DDIR}/${OUTFILE}.root\", \"TITLE\" )" >> ${DDIR}/${OUTFILE}.log
fi

echo "$(inspect_executables)" >> ${DDIR}/${OUTFILE}.log

# log file into root file
$EVNDISPSYS/bin/logFile \
    anasumLog \
    ${DDIR}/${OUTFILE}.root \
    ${DDIR}/${OUTFILE}.log

exit
