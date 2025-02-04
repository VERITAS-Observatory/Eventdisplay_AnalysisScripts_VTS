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
IRFVERSION=VERSIONIRF
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
    DDIR="$TMPDIR/TABLES_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
else
    DDIR="/tmp/TABLES_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:${DDIR}"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=${DDIR},CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
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
        ls -l ${EVNDISPSYS}/bin/mscw_energy
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
            cp -v -f $F ${DDIR}/
            ofile=$(basename $F .zst)
            zstd -d ${DDIR}/${ofile}.zst -o ${DDIR}/${ofile}
        done
    else
        echo "Error: no zstd installation"
        exit
    fi
fi
rm -f "$DDIR/$OFILE.list"
ls -1 "$DDIR"/*[0-9].root > "$DDIR/$OFILE.list"

# Redo stereo reconstruction with diff cuts on images (versions after v490)
MOPT=""
if [[ $IRFVERSION != v490* ]]; then
    MOPT="-redo_stereo_reconstruction -minangle_stereo_reconstruction=10"
    MOPT="$MOPT -maxloss=0.4 -use_evndisp_selected_images=0"
    MOPT="$MOPT -maxdist=1.75 -minntubes=5 -minwidth=0.02 -minsize=100"
fi

echo "Running mscw_energy (table filling)"
logfile="$ODIR/$TABFILE.log"
$EVNDISPSYS/bin/mscw_energy -filltables=1 \
                            -limitEnergyReconstruction \
                            -write1DHistograms \
                            -inputfilelist "$DDIR/$OFILE.list" \
                            -tablefile "${DDIR}/$TABFILE.root" \
                            -ze=$ZA $MOPT \
                            -arrayrecid=$RECID \
                            -woff=$WOBBLE &> "$logfile"

echo "$(inspect_executables)" >> "$logfile"
$EVNDISPSYS/bin/logFile makeTableLog "${DDIR}/$TABFILE.root" "$logfile"
mv -v -f "${DDIR}/$TABFILE.root" "${ODIR}/$TABFILE.root"
