#!/bin/bash
# script to analyse files with lookup tables

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
TABFILE=TABLEFILE
RECID=RECONSTRUCTIONID
ODIR=OUTPUTDIRECTORY
INFILE=EVNDISPFILE
INLOGDIR=INPUTLOGDIR
DISPDIR=DISPBDT

INDIR=`dirname $INFILE`
BFILE=`basename $INFILE .root`

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
mkdir -p $TEMPDIR

#################################
# run analysis

MSCWLOGFILE="$ODIR/$BFILE.mscw.log"
rm -f $MSCWLOGFILE
cp -f -v $INFILE $TEMPDIR

MSCWDATAFILE="$ODIR/$BFILE.mscw.root"

MOPT=""
if [[ DISPBDT != "NOTSET" ]]; then
    MOPT="-redo_stereo_reconstruction"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    MOPT="$MOPT -tmva_disperror_weight 50"
    # note: loss cuts needs to be equivalent to that used in training
    MOPT="$MOPT -maxloss=0.2"
    # MOPT="$MOPT -disp_use_intersect"
    MOPT="$MOPT -tmva_filename_stereo_reconstruction $DISPDIR/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction $DISPDIR/BDTDispError_BDT_"
    MOPT="$MOPT -tmva_filename_dispsign_reconstruction $DISPDIR/BDTDispSign_BDT_"
    echo "DISP BDT options: $MOPT"
fi

$EVNDISPSYS/bin/mscw_energy         \
    ${MOPT} \
    -tablefile $TABFILE             \
    -arrayrecid=$RECID              \
    -inputfile $TEMPDIR/$BFILE.root \
    -writeReconstructedEventsOnly=1 &> $MSCWLOGFILE

# move logfiles into output file
if [[ -e ${INLOGDIR}/$BFILE.log ]]; then
  $EVNDISPSYS/bin/logFile evndispLog $TEMPDIR/$BFILE.mscw.root ${INLOGDIR}/$BFILE.log
fi
if [[ -e $MSCWLOGFILE ]]; then
  $EVNDISPSYS/bin/logFile mscwTableLog $TEMPDIR/$BFILE.mscw.root $MSCWLOGFILE
fi

# move output file from scratch and clean up
cp -f -v $TEMPDIR/$BFILE.mscw.root $MSCWDATAFILE
rm -f $TEMPDIR/$BFILE.mscw.root
rm -f $TEMPDIR/$BFILE.root
    
# write info to log
echo "RUN$BFILE MSCWLOG $MSCWLOGFILE"
echo "RUN$BFILE MSCWDATA $MSCWDATAFILE"

exit
