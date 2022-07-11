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
NROOTFILES=NFILES
RECID="RECONSTRUCTIONID"

# output directory
OSUBDIR="$ODIR/MSCW_RECID$RECID"
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

# input evndisp files
rm -f $OSUBDIR/$OFILE.log
rm -f $OSUBDIR/$OFILE.list
if [ -n "$(find ${INDIR} -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Using evndisp root files from ${INDIR}"
    ls -1 ${INDIR}/*[0-9].root > $OSUBDIR/$OFILE.list
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
    ls -1 ${TMPDIR}/*[0-9].root > $OSUBDIR/$OFILE.list
fi


# run mscw_energy
outputfilename="$DDIR/$OFILE.mscw.root"
logfile="$OSUBDIR/$OFILE.log"
$EVNDISPSYS/bin/mscw_energy $MOPT -inputfilelist $OSUBDIR/$OFILE.list -outputfile $outputfilename -noise=$NOISE &> $logfile

# cp results file back to data directory and clean up
outputbasename=$( basename $outputfilename )
cp -f -v $outputfilename $OSUBDIR/$outputbasename
rm -f "$outputfilename"
rmdir $DDIR
chmod g+w "$OSUBDIR/$outputbasename"
chmod g+w "$logfile"

exit
