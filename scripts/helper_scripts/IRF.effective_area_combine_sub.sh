#!/bin/bash
# combine effective areas

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
EAFILES=INPUTFILES
OFILE=OUTPUTFILE
ODIR=OUTPUTDIR

DDIR=$(dirname "$EAFILES" | sort -u)
OPTODIR="$ODIR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:/opt/DDIR "
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=/opt/DDIR,CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
    CALDIR="/opt/ODIR"
    DDIR="/opt/DDIR/"
    OPTODIR="/opt/ODIR/"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

# combine effective areas (reduced file size with TH2F replaced by arrays)
mkdir -p $ODIR
chmod -R g+w $ODIR
ls -1 $EAFILES > "$ODIR"/"$OFILE".list
echo "Found $(cat $ODIR/$OFILE.list | wc -l) input files to merge"
echo "File list: $ODIR/$OFILE.list"

$EVNDISPSYS/bin/combineEffectiveAreas "$OPTODIR/$OFILE.list" ${OPTODIR}/$OFILE DL3reduced &> ${ODIR}/$OFILE.log

# log files
echo "$(inspect_executables)" >> "$ODIR/$OFILE.log"
$EVNDISPSYS/bin/logFile effAreaCombineLog "${OPTODIR}/$OFILE.root" "${OPTODIR}/$OFILE.log"
