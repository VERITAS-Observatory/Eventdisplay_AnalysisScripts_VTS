#!/bin/bash
# shellcheck disable=SC2086
# EVNDISPSYS may include an apptainer exec prefix and must split into command words.
# combine lookup tables

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
# shellcheck source=/dev/null
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
FLIST=TABLELIST
OFILE=OUTPUTFILE
ODIR=OUTPUTDIR

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/combineTables"
else
    DDIR="/tmp/combineTables"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:${DDIR} "
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=/opt/DDIR,CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l "${EVNDISPSYS}"/bin/evndisp
    fi
}

# copy table files to temp
xargs -a "$ODIR/$FLIST" cp -t "$DDIR"
ls -1 "${DDIR}"/*.root > "$DDIR/$FLIST"

# combine the tables
$EVNDISPSYS/bin/combineLookupTables "$DDIR/$FLIST" "$DDIR/$OFILE.root" median &> "$ODIR/$OFILE.log"

# log files
inspect_executables >> "$ODIR/$OFILE.log"
cp -v "$ODIR/$OFILE.log" "$DDIR/$OFILE.log"
$EVNDISPSYS/bin/logFile makeTableCombineLog "$DDIR/$OFILE.root" "$DDIR/$OFILE.log"
$EVNDISPSYS/bin/logFile makeTableFileList "$DDIR/$OFILE.root" "$DDIR/$FLIST"

# cleanup
mv -f -v "$DDIR/$OFILE.root" "$ODIR/$OFILE.root"
