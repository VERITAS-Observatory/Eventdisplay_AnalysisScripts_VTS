#!/bin/bash
# analyse MC files with lookup tables

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
TABFILE=TABLEFILE
ZA=ZENITHANGLE
NOISE=NOISELEVEL
WOBBLE=WOBBLEOFFSET
ANATYPE=ANALYSISTYPE
NROOTFILES=NFILES
EPOCH="ARRAYEPOCH"
ATM=ATMOSPHERE
RECID="RECONSTRUCTIONID"
SIMTYPE=SIMULATIONTYPE
DISPBDT=USEDISP
INDIR=INPUTDIR
ODIR=OUTPUTDIR

# output directory
OSUBDIR="$ODIR/MSCW_RECID${RECID}"
if [ $DISPBDT -eq 1 ]; then
    OSUBDIR="${OSUBDIR}_DISP"
fi
mkdir -p "$OSUBDIR"
chmod g+w "$OSUBDIR"
echo "Output directory for data products: " $OSUBDIR

# file names
OFILE="${ZA}deg_${WOBBLE}wob_NOISE${NOISE}"

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
else
    DDIR="/tmp/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
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
    TABFILE="/opt/VERITAS_EVNDISP_AUX_DIR/Tables/$(basename $TABFILE)"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/mscw_energy
    fi
}


# mscw_energy command line options
MOPT="-noNoTrigger -nomctree -writeReconstructedEventsOnly=1 -arrayrecid=${RECID} -tablefile $TABFILE"
# dispBDT reconstruction
if [ $DISPBDT -eq 1 ]; then
    MOPT="$MOPT -redo_stereo_reconstruction"
    MOPT="$MOPT -tmva_disperror_weight 50"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    MOPT="$MOPT -maxdist=1.75 -minntubes=5 -minwidth=0.02 -minsize=100"
    MOPT="$MOPT -maxloss=0.40"
    MOPT="$MOPT -use_evndisp_selected_images=0"
    # MOPT="$MOPT -maxnevents=1000"
    if [[ ${SIMTYPE} == *"RedHV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}_redHV/"
    elif [[ ${SIMTYPE} == *"UV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}_UV/"
    else
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}/"
    fi
    if [[ "${ZA}" -lt "38" ]]; then
        DISPDIR="${DISPDIR}/SZE/"
    elif [[ "${ZA}" -lt "48" ]]; then
        DISPDIR="${DISPDIR}/MZE/"
    elif [[ "${ZA}" -lt "58" ]]; then
        DISPDIR="${DISPDIR}/LZE/"
    else
        DISPDIR="${DISPDIR}/XZE/"
    fi
    # unzip XML files into DDIR
    cp -v -f ${DISPDIR}/*.xml.gz ${DDIR}/
    gunzip -v ${DDIR}/*xml.gz
    MOPT="$MOPT -tmva_filename_stereo_reconstruction ${DDIR}/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction ${DDIR}/BDTDispError_BDT_"
    MOPT="$MOPT -tmva_filename_dispsign_reconstruction ${DDIR}/BDTDispSign_BDT_"
    MOPT="$MOPT -tmva_filename_energy_reconstruction ${DDIR}/BDTDispEnergy_BDT_"
    echo "DISP BDT options: $MOPT"
fi

# input evndisp files
rm -f $OSUBDIR/$OFILE.log
rm -f $OSUBDIR/$OFILE.list
echo "INDIR ${INDIR}"
if [ -n "$(find "${INDIR}/" -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Using evndisp root files from ${INDIR}"
    cp -v "${INDIR}/*[0-9].root" "$DDIR"
elif [ -n "$(find  "${INDIR}/" -name "*[0-9].root.zst" 2>/dev/null)" ]; then
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
ls -1 "$DDIR"/*[0-9].root > "$DDIR/$OFILE.list"
echo "Evndisp files:"
cat "$DDIR/$OFILE.list"

# run mscw_energy
outputfilename="$DDIR/$OFILE.mscw.root"
logfile="$OSUBDIR/$OFILE.log"
$EVNDISPSYS/bin/mscw_energy $MOPT \
    -inputfilelist "$DDIR/$OFILE.list" \
    -outputfile $outputfilename \
    -noise=$NOISE &> $logfile

echo "READING evndisp files from ${INDIR}" >> $logfile
# add DISP directory to log file
# (as XML files are unpacked to tmp directory)
if [ $DISPBDT -eq 1 ]; then
    echo "Reading DISPBDT XML files from ${DISPDIR}" >> $logfile
fi

echo "$(inspect_executables)" >> "$logfile"
cp -v "$logfile" "$DDIR/$OFILE.log"
$EVNDISPSYS/bin/logFile mscwTableLog $outputfilename "$DDIR/$OFILE.log"

# cp results file back to data directory and clean up
outputbasename=$( basename $outputfilename )
cp -f -v $outputfilename $OSUBDIR/$outputbasename
cp -f -v "$DDIR/$OFILE.log" "$logfile"
rm -f "$outputfilename"
chmod g+w "$OSUBDIR/$outputbasename"
chmod g+w "$logfile"
