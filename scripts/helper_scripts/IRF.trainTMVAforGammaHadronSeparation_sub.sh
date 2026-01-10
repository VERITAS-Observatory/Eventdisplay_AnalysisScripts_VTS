#!/bin/bash
# script to train TMVA (BDTs) for gamma/hadron separation

RXPAR=RUNPARAM
SIMDIR=MCDIRECTORY
DDIR=DATADIRECTORY
ODIR=OUTPUTDIR

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

ODIR=$(dirname $RXPAR)
LDIR=$(dirname $RXPAR)
LXPAR="$RXPAR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${SIMDIR}:/opt/SIMDIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:/opt/DDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=/opt/DDIR,CALDIR=/opt/ODIR,SIMDIR=/opt/SIMDIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
    CALDIR="/opt/ODIR"

    SIMDIR="/opt/SIMDIR"
    ODIR="/opt/ODIR"
    DDIR="/opt/DDIR"

    RXPAR="/opt/ODIR/"$(basename $RXPAR)
fi

cp "$LXPAR".runparameter "$LXPAR".runparameter.run
sed -i "s|SIMDIR|${SIMDIR}|" "${LXPAR}".runparameter.run
sed -i "s|ODIR|${ODIR}|" "${LXPAR}".runparameter.run
sed -i "s|DDIR|${DDIR}|" "${LXPAR}".runparameter.run


inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

rm -f "$LDIR"/$(basename $RXPAR)"_preselect.log"
eval "$EVNDISPSYS"/bin/trainTMVAforGammaHadronSeparation "$RXPAR".runparameter.run WRITETRAININGEVENTS > "$LDIR"/$(basename $RXPAR)"_preselect.log"

rm -f "$LDIR"/$(basename $RXPAR)".log"
eval "$EVNDISPSYS"/bin/trainTMVAforGammaHadronSeparation "$RXPAR".runparameter.run > "$LDIR"/$(basename $RXPAR)".log"

echo "$(inspect_executables)" >> "$LDIR"/$(basename $RXPAR)".log"
eval "$EVNDISPSYS"/bin/logFile tmvaLog "$RXPAR".root "$RXPAR".log

# remove unnecessary *.C files
CDIR=`dirname $RXPAR`
rm -f -v "$CDIR"/$ONAME*.C
