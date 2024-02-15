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
mkdir -p $(dirname "$OUTFILE")
# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=${TMPDIR}/MSCWDISP-$(uuidgen)
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR/MSCWDISP-$(uuidgen)"
fi
mkdir -p $TEMPDIR

OUTPUTDATAFILE="$OUTFILE"
OUTPUTLOGFILE="$OUTFILE.log"
rm -f ${OUTPUTLOGFILE}

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind $(dirname $OUTFILE):/opt/ODIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${DDIR}:/opt/DDIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${TEMPDIR}:/opt/TEMPDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_DATA_DIR=/opt/VERITAS_DATA_DIR,VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,VERITASODIR=/opt/ODIR,INDIR=/opt/INDIR,TEMPDIR=/opt/TEMPDIR,LOGDIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    DDIR="/opt/DDIR/"
    echo "APPTAINER DDIR: $DDIR"
    OUTPUTDATAFILE="/opt/ODIR/$(basename $OUTFILE)"
    echo "APPTAINER ODIR: $OUTPUTDATAFILE"
fi

# determine if this is a short or long run list
# (use VERSION string to identify long run list)
NV=$(grep -c "VERSION" ${RUNLIST})
if [ $NV -eq 0 ]; then
    RUNLISTSTRING="-k"
else
    RUNLISTSTRING="-l"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/anasum
    fi
}
# copy file list, runparameter and time masks file to tmp disk
cp -v "$RUNLIST" "$TEMPDIR"
RUNLIST="${TEMPDIR}/$(basename $RUNLIST)"
cp -v "$RUNP" "$TEMPDIR"
cp -v $(dirname $RUNP)/$(grep TIMEMASKFILE $RUNP | awk '{print $3}') "$TEMPDIR"
RUNP="${TEMPDIR}/$(basename $RUNP)"

$EVNDISPSYS/bin/anasum \
    -i 1 \
    ${RUNLISTSTRING} ${RUNLIST} \
    -d ${DDIR} \
    -f ${RUNP} \
    -o ${OUTPUTDATAFILE}.root 2>&1 | tee ${OUTPUTLOGFILE}

echo "$(inspect_executables)" >> ${OUTFILE}.log

# log file into root file
$EVNDISPSYS/bin/logFile \
    anasumLog \
    ${OUTPUTDATAFILE}.root \
    ${OUTPUTDATAFILE}.log

exit
