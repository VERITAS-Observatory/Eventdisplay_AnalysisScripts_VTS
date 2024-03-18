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

getNumberedDirectory()
{
    TRUN="$1"
    IDIR="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${IDIR}/${TRUN:0:1}/"
    else
        ODIR="${IDIR}/${TRUN:0:2}/"
    fi
    echo ${ODIR}
}

OUTPUTDATAFILE="$OUTFILE"
OUTPUTLOGFILE="$OUTFILE.log"
rm -f ${OUTPUTLOGFILE}
touch ${OUTPUTLOGFILE}

# copy all files to TMPDIR (as anasum cannot access subdirectories
# as used in pre-processing)
RUNS=$(cat "$RUNLIST")
for R in $RUNS; do
    if [[ -e "$DDIR/$R.anasum.root" ]]; then
        cp -f -v "$DDIR/$R.anasum.root" "$TEMPDIR"
    else
        FIL="$(getNumberedDirectory $R ${DDIR})/${R}.anasum.root"
        if [[ -e "$FIL" ]]; then
            cp -f -v "$FIL" "$TEMPDIR"
        else
            echo "ERROR: Run $R not found in $DDIR or $FIL" >> ${OUTPUTLOGFILE}
        fi
    fi
done
if [[ $(wc -l < "${OUTPUTLOGFILE}") -ne 0 ]]; then
    echo "Not all runs found on disk"
    echo "exiting..."
    exit
fi

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind $(dirname $OUTFILE):/opt/ODIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${TEMPDIR}:/opt/DDIR "
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

# for Crab runs: print sensitivity estimate
RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${DDIR}/${OUTFILE}.root -runinfo)
TMPTARGET=$(echo $RUNINFO | cut -d\  -f7- )
if [[ ${TMPTARGET} == "Crab" ]]; then
    echo "========================== SENSITIVITY ESTIMATE ==========================" >> ${OUTFILE}.log
    $EVNDISPSYS/bin/printCrabSensitivity ${DDIR}/${OUTFILE}.root >> ${OUTFILE}.log
    echo "========================== ==========================" >> ${OUTFILE}.log
fi

echo "$(inspect_executables)" >> ${OUTFILE}.log

# log file into root file
$EVNDISPSYS/bin/logFile \
    anasumLog \
    ${OUTPUTDATAFILE}.root \
    ${OUTPUTDATAFILE}.log

exit
