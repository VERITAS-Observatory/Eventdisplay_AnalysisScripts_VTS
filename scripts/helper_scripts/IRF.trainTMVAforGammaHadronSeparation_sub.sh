#!/bin/bash
# script to train TMVA (BDTs) for gamma/hadron separation

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:/opt/DDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=/opt/DDIR,CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
    CALDIR="/opt/ODIR"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

# parameters replaced by parent script using sed
RXPAR=RUNPARAM

"$EVNDISPSYS"/bin/trainTMVAforGammaHadronSeparation "$RXPAR".runparameter WRITETRAININGEVENTS > "$RXPAR"_preselect.log

"$EVNDISPSYS"/bin/trainTMVAforGammaHadronSeparation "$RXPAR".runparameter > "$RXPAR".log

echo "$(inspect_executables)" >> "$ODIR/$TABFILE.log"
"$EVNDISPSYS"/bin/logFile tmvaLog "$RXPAR".root "$RXPAR".log

# remove unnecessary *.C files
CDIR=`dirname $RXPAR`
rm -f -v "$CDIR"/$ONAME*.C
