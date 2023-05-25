#!/bin/bash
# script to analyse files with lookup tables

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS
set -e

# parameters replaced by parent script using sed
RECID=RECONSTRUCTIONID
ODIR=OUTPUTDIRECTORY
INFILE=EVNDISPFILE
INLOGDIR=INPUTLOGDIR
DISPBDT=BDTDISP
IRFVERSION=VERSIONIRF

# default simulation types
SIMTYPE_DEFAULT_V4="GRISU"
SIMTYPE_DEFAULT_V5="GRISU"
SIMTYPE_DEFAULT_V6="CARE_June2020"
SIMTYPE_DEFAULT_V6_REDHV="CARE_RedHV"
SIMTYPE_DEFAULT_V6_UV="CARE_UV_2212"

ANATYPE="AP"
if [[ ! -z  $VERITAS_ANALYSIS_TYPE ]]; then
   ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
fi

INDIR=`dirname $INFILE`
BFILE=`basename $INFILE .root`

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
mkdir -p $TEMPDIR

RUNINFO=$($EVNDISPSYS/bin/printRunParameter $INFILE -updated-runinfo)
EPOCH=`echo $RUNINFO | awk '{print $(1)}'`
ATMO=${FORCEDATMO:-`echo $RUNINFO | awk '{print $(3)}'`}
HVSETTINGS=`echo $RUNINFO | awk '{print $(4)}'`
if [[ $ATMO == *error* ]]; then
    echo "error finding atmosphere; skipping run $BFILE"
    exit
fi

# simulation type
if [ "$EPOCH" == "V4" ]
then
    SIMTYPE_RUN="$SIMTYPE_DEFAULT_V4"
elif [ "$EPOCH" == "V5" ]
then
    SIMTYPE_RUN="$SIMTYPE_DEFAULT_V5"
else
    if [ "$HVSETTINGS" == "obsLowHV" ]; then
        SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6_REDHV"
    elif [ "$HVSETTINGS" == "obsFilter" ]; then
        SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6_UV"
        ATMO="21"
    else
        SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6"
    fi
fi

TABFILE=table-${IRFVERSION}-auxv01-${SIMTYPE_RUN}-ATM${ATMO}-${EPOCH}-${ANATYPE}.root
echo "TABLEFILE: $TABFILE"
# Check that table file exists
if [[ "$TABFILE" == `basename $TABFILE` ]]; then
    TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
fi
if [ ! -f "$TABFILE" ]; then
    echo "Error, table file '$TABFILE' not found, exiting..."
    exit 1
fi

get_disp_dir()
{
    if [ "$HVSETTINGS" == "obsLowHV" ]; then
        DISPDIR="DispBDTs/${EPOCH}_ATM${ATMO}_${ANATYPE}_redHV/"
    elif [ "$HVSETTINGS" == "obsFilter" ]; then
        DISPDIR="DispBDTs/${EPOCH}_ATM${ATMO}_UV/"
    else
        DISPDIR="DispBDTs/${EPOCH}_ATM${ATMO}_${ANATYPE}/"
    fi
    ZA=$($EVNDISPSYS/bin/printRunParameter $INFILE -elevation | awk '{print $3}')
    if (( $(echo "90.-$ZA < 38" |bc -l) )); then
        DISPDIR="${DISPDIR}/SZE/"
    elif (( $(echo "90.-$ZA < 48" |bc -l) )); then
        DISPDIR="${DISPDIR}/MZE/"
    elif (( $(echo "90.-$ZA < 58" |bc -l) )); then
        DISPDIR="${DISPDIR}/LZE/"
    else
        DISPDIR="${DISPDIR}/XZE/"
    fi
    echo "${VERITAS_EVNDISP_AUX_DIR}/${DISPDIR}/"
}

if [[ $DISPBDT == "1" ]]; then
    DISPDIR=$(get_disp_dir)
    echo "DISPDIR (Elevation is $ZA deg): " $DISPDIR
fi

#################################
# run analysis

MSCWLOGFILE="$ODIR/$BFILE.mscw.log"
rm -f ${MSCWLOGFILE}
cp -f -v $INFILE $TEMPDIR

MSCWDATAFILE="$ODIR/$BFILE.mscw.root"

MOPT=""
if [[ DISPBDT != "0" ]]; then
    MOPT="-redo_stereo_reconstruction"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    MOPT="$MOPT -tmva_disperror_weight 50"
    # note: loss cuts needs to be equivalent to that used in training
    MOPT="$MOPT -maxloss=0.2"
    # MOPT="$MOPT -disp_use_intersect"
    # unzip xml files
    cp -v -f ${DISPDIR}/*.xml.gz ${TEMPDIR}/
    gunzip -v ${TEMPDIR}/*.xml.gz
    MOPT="$MOPT -tmva_filename_stereo_reconstruction ${TEMPDIR}/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction ${TEMPDIR}/BDTDispError_BDT_"
    MOPT="$MOPT -tmva_filename_dispsign_reconstruction ${TEMPDIR}/BDTDispSign_BDT_"
    echo "DISP BDT options: $MOPT"
fi

$EVNDISPSYS/bin/mscw_energy         \
    ${MOPT} \
    -tablefile $TABFILE             \
    -arrayrecid=$RECID              \
    -inputfile $TEMPDIR/$BFILE.root \
    -writeReconstructedEventsOnly=1 &> ${MSCWLOGFILE}

# write DISP directory into log file (as tmp directories are used)
if [[ DISPBDT != "NOTSET" ]]; then
    echo "" >> ${MSCWLOGFILE}
    echo "dispBDT XML files read from ${DISPDIR}" >> ${MSCWLOGFILE}
fi

# move logfiles into output file
if [[ -e ${INLOGDIR}/$BFILE.log ]]; then
  $EVNDISPSYS/bin/logFile evndispLog $TEMPDIR/$BFILE.mscw.root ${INLOGDIR}/$BFILE.log
fi
if [[ -e ${MSCWLOGFILE} ]]; then
  $EVNDISPSYS/bin/logFile mscwTableLog $TEMPDIR/$BFILE.mscw.root ${MSCWLOGFILE}
fi

# move output file from scratch and clean up
cp -f -v $TEMPDIR/$BFILE.mscw.root $MSCWDATAFILE
rm -f $TEMPDIR/$BFILE.mscw.root
rm -f $TEMPDIR/$BFILE.root
    
# write info to log
echo "RUN$BFILE MSCWLOG ${MSCWLOGFILE}"
echo "RUN$BFILE MSCWDATA $MSCWDATAFILE"

exit
