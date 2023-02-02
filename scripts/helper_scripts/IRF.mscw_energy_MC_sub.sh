#!/bin/bash
# script to analyse MC files with lookup tables

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
INDIR=INPUTDIR
ODIR=OUTPUTDIR
TABFILE=TABLEFILE
ZA=ZENITHANGLE
NOISE=NOISELEVEL
WOBBLE=WOBBLEOFFSET
ANATYPE=ANALYSISTYPE
NROOTFILES=NFILES
RECID="RECONSTRUCTIONID"
EPOCH="ARRAYEPOCH"
ATM="ATMOS"
DISPBDT=USEDISP

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

# mscw_energy command line options
MOPT="-noNoTrigger -nomctree -writeReconstructedEventsOnly=1 -arrayrecid=${RECID} -tablefile $TABFILE"
echo "MSCW options: $MOPT"

# dispBDT reconstruction
# note: loss cuts needs to be equivalent to that used in training
if [ $DISPBDT -eq 1 ]; then
    MOPT="$MOPT -redo_stereo_reconstruction"
    MOPT="$MOPT -tmva_disperror_weight 50"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    MOPT="$MOPT -maxloss=0.2"
    # MOPT="$MOPT -disp_use_intersect"
    # MOPT="$MOPT -maxnevents=1000"
    if [[ ${EPOCH} == *"redHV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${EPOCH}_ATM${ATM}_${ANATYPE}_redHV/"
    else
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${EPOCH}_ATM${ATM}_${ANATYPE}/"
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
    # unzip XML files into tmpdir
    cp -v -f ${DISPDIR}/*.xml.gz ${DDIR}/
    gunzip -v ${DDIR}/*xml.gz
    MOPT="$MOPT -tmva_filename_stereo_reconstruction ${DDIR}/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction ${DDIR}/BDTDispError_BDT_"
    MOPT="$MOPT -tmva_filename_dispsign_reconstruction ${DDIR}/BDTDispSign_BDT_"
    echo "DISP BDT options: $MOPT"
fi

# input evndisp files
rm -f $OSUBDIR/$OFILE.log
rm -f $OSUBDIR/$OFILE.list
echo "INDIR ${INDIR}"
if [ -n "$(find "${INDIR}/" -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Using evndisp root files from ${INDIR}"
    ls -1 ${INDIR}/*[0-9].root > $OSUBDIR/$OFILE.list
elif [ -n "$(find  "${INDIR}/" -name "*[0-9].root.zst" 2>/dev/null)" ]; then
    if command -v zstd /dev/null; then
        echo "Copying evndisp root.zst files to ${TMPDIR}"
        FLIST=$(find "${INDIR}/" -name "*[0-9].root.zst")
        for F in $FLIST
        do
            echo "unpacking $F"
            ofile=$(basename $F .zst)
            zstd -d $F -o ${TMPDIR}/${ofile}
        done
    else
        echo "Error: no zstd installation"
        exit
    fi
    ls -1 ${TMPDIR}/*[0-9].root > $OSUBDIR/$OFILE.list
fi
echo "Evndisp files:"
cat $OSUBDIR/$OFILE.list

# run mscw_energy
outputfilename="$DDIR/$OFILE.mscw.root"
logfile="$OSUBDIR/$OFILE.log"
$EVNDISPSYS/bin/mscw_energy $MOPT \
    -inputfilelist $OSUBDIR/$OFILE.list \
    -outputfile $outputfilename \
    -noise=$NOISE &> $logfile

$EVNDISPSYS/bin/logFile mscwTableLog $outputfilename $logfile

# cp results file back to data directory and clean up
outputbasename=$( basename $outputfilename )
cp -f -v $outputfilename $OSUBDIR/$outputbasename
rm -f "$outputfilename"
rmdir $DDIR
chmod g+w "$OSUBDIR/$outputbasename"
chmod g+w "$logfile"

exit
