#!/bin/bash
# fill lookup tables

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
ZA=ZENITHANGLE
NOISE=NOISELEVEL
WOBBLE=WOBBLEOFFSET
EPOCH="ARRAYEPOCH"
ATM=ATMOSPHERE
RECID="RECONSTRUCTIONID"
SIMTYPE=SIMULATIONTYPE
INDIR=INPUTDIR
ODIR=OUTPUTDIR

TABFILE="table_${SIMTYPE}_${ZA}deg_${WOBBLE}wob_noise${NOISE}_${EPOCH}_ATM${ATM}_ID${RECID}"

echo "Cluster ID ${ClusterId}"
echo "PROCESS ID ${ProcId}"

# remove existing log and table file
rm -f "$ODIR/$TABFILE.root"
rm -f "$ODIR/$TABFILE.log"

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/evndispfiles"
else
    DDIR="/tmp/evndispfiles"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

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


if [ -n "$(find ${INDIR} -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Copying evndisp root files to ${DDIR}"
    find ${INDIR} -name "*[0-9].root" -exec cp -v {} ${DDIR} \;
elif [ -n "$(find  ${INDIR} -name "*[0-9].root.zst" 2>/dev/null)" ]; then
    if command -v zstd /dev/null; then
        echo "Copying evndisp root.zst files to ${DDIR}"
        FLIST=$(find "${INDIR}/" -name "*[0-9].root.zst")
        for F in $FLIST
        do
            echo "unpacking $F"
            ofile=$(basename $F .zst)
            zstd -d $F -o ${DDIR}/${ofile}
        done
    else
        echo "Error: no zstd installation"
        exit
    fi
fi

# Redo stereo reconstruction with diff cuts on images
MOPT="-redo_stereo_reconstruction -minangle_stereo_reconstruction=10"
MOPT="$MOPT -maxloss=0.4 -use_evndisp_selected_images=0"
MOPT="$MOPT -maxdist=1.75 -minntubes=5 -minwidth=0.02 -minsize=100"

# make the table part
$EVNDISPSYS/bin/mscw_energy -filltables=1 \
                            -limitEnergyReconstruction \
                            -write1DHistograms \
                            -inputfile "${DDIR}/*[0-9].root" \
                            -tablefile "${DDIR}/$TABFILE.root" \
                            -ze=$ZA $MOPT \
                            -arrayrecid=$RECID \
                            -woff=$WOBBLE &> "$ODIR/$TABFILE.log"

echo "$(inspect_executables)" >> "$ODIR/$TABFILE.log"
cp -v "$ODIR/$TABFILE.log" "$DDIR/$TABFILE.log"
$EVNDISPSYS/bin/logFile mscwTableFillLow "${DDIR}/$TABFILE.root" "$DDIR/$TABFILE.log"
mv -v -f "${DDIR}/$TABFILE.root" "${ODIR}/$TABFILE.root"
