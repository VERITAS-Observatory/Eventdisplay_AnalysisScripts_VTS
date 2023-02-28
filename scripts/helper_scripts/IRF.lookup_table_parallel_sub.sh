#!/bin/bash
# script to run over all zenith angles and telescope combinations and create lookup tables 

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
ZA=ZENITHANGLE
WOBBLE=WOBBLEOFFSET
NOISE=NOISELEVEL
EPOCH=ARRAYEPOCH
ATM=ATMOSPHERE
RECID=RECONSTRUCTIONID
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
echo $PATH

if [ -n "$(find ${INDIR} -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Copying evndisp root files to ${TMPDIR}"
    find ${INDIR} -name "*[0-9].root" -exec cp -v {} ${TMPDIR} \;
elif [ -n "$(find  ${INDIR} -name "*[0-9].root.zst" 2>/dev/null)" ]; then
    if command -v zstd /dev/null; then
        echo "Copying evndisp root.zst files to ${TMPDIR}"
        FLIST=$(find ${INDIR} -name "*[0-9].root.zst")
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
fi


# make the table part
# v5x versions: parameter -limitEnergyReconstruction is obsolete
$EVNDISPSYS/bin/mscw_energy -filltables=1 \
                            -limitEnergyReconstruction \
                            -write1DHistograms \
                            -inputfile "${TMPDIR}/*[0-9].root" \
                            -tablefile "$ODIR/$TABFILE.root" \
                            -ze=$ZA \
                            -arrayrecid=$RECID \
                            -woff=$WOBBLE &> "$ODIR/$TABFILE.log"

$EVNDISPSYS/bin/logFile mscwTableFillLow "$ODIR/$TABFILE.root" "$ODIR/$TABFILE.log"

exit
