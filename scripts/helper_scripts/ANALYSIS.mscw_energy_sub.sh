#!/bin/bash
# script to analyse files with lookup tables

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source $EVNDISPSYS/setObservatory.sh VTS
fi
set -e

# parameters replaced by parent script using sed
RECID=RECONSTRUCTIONID
ODIR=OUTPUTDIRECTORY
INFILE=EVNDISPFILE
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
INFILEPATH="$INFILE"

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=${TMPDIR}/MSCWDISP-$(uuidgen)
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR/MSCWDISP-$(uuidgen)"
fi
mkdir -p $TEMPDIR

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${INDIR}:/opt/INDIR "
    APPTAINER_MOUNT+=" --bind ${TEMPDIR}:/opt/TEMPDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_DATA_DIR=/opt/VERITAS_DATA_DIR,VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,VERITASODIR=/opt/ODIR,INDIR=/opt/INDIR,TEMPDIR=/opt/TEMPDIR,LOGDIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    INFILEPATH="/opt/INDIR/$BFILE.root"
    echo "APPTAINER INFILEPATH: $INFILEPATH"
fi

echo "READING RUNINFO from $INFILEPATH"
RUNINFO=$($EVNDISPSYS/bin/printRunParameter $INFILEPATH updated-runinfo)
EPOCH=`echo $RUNINFO | awk '{print $(1)}'`
ATMO=${FORCEDATMO:-`echo $RUNINFO | awk '{print $(3)}'`}
HVSETTINGS=`echo $RUNINFO | awk '{print $(4)}'`
if [[ $ATMO == *error* ]]; then
    echo "error finding atmosphere; skipping run $BFILE"
    exit
fi
echo "RUNINFO $EPOCH $ATMO $HVSETTINGS"

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
        ATMO="61"
    else
        SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6"
    fi
fi

TABFILE=table-${IRFVERSION}-auxv01-${SIMTYPE_RUN}-ATM${ATMO}-${EPOCH}-${ANATYPE}.root
echo "TABLEFILE: $TABFILE"
# Check that table file exists
if [[ "$TABFILE" == $(basename $TABFILE) ]]; then
    TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
fi
echo "TABLEFILE $TABFILE"
if [ ! -f "$TABFILE" ]; then
    echo "Error, table file '$TABFILE' not found, exiting..."
    exit 1
fi
if [ -n "$EVNDISP_APPTAINER" ]; then
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

get_disp_dir()
{
    if [ "$HVSETTINGS" == "obsLowHV" ]; then
        DISPDIR="DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATMO}_redHV/"
    elif [ "$HVSETTINGS" == "obsFilter" ]; then
        DISPDIR="DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATMO}_UV/"
    else
        DISPDIR="DispBDTs//${ANATYPE}/${EPOCH}_ATM${ATMO}/"
    fi
    ZA=$($EVNDISPSYS/bin/printRunParameter $INFILEPATH -elevation | awk '{print $3}')
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
echo "MSCWDATAFILE $MSCWDATAFILE"

MOPT=""
if [[ DISPBDT != "0" ]]; then
    MOPT="-redo_stereo_reconstruction"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    MOPT="$MOPT -tmva_disperror_weight 50"
    # note: loss cuts needs to be equivalent to that used in training
    MOPT="$MOPT -maxloss=0.2"
    # MOPT="$MOPT -minwidth=0.02"
    MOPT="$MOPT -minfui=0.2"
    # MOPT="$MOPT -minfitstat=3"
    # looser cuts in mscw
    # MOPT="$MOPT -maxloss=0.5"
    # MOPT="$MOPT -use_evndisp_selected_images=0"
    # # use interset
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
    -updateEpoch=1 \
    -tablefile $TABFILE             \
    -arrayrecid=$RECID              \
    -inputfile $TEMPDIR/$BFILE.root \
    -writeReconstructedEventsOnly=1 &> ${MSCWLOGFILE}

echo "$(inspect_executables)" >> ${MSCWLOGFILE}

# write DISP directory into log file (as tmp directories are used)
if [[ DISPBDT != "NOTSET" ]]; then
    echo "" >> ${MSCWLOGFILE}
    echo "dispBDT XML files read from ${DISPDIR}" >> ${MSCWLOGFILE}
fi
echo "EVNDISP file: ${INFILE}" >> ${MSCWLOGFILE}
echo "VERITAS_EVNDISP_AUX: ${VERITAS_EVNDISP_AUX_DIR}" >> ${MSCWLOGFILE}
echo "VERITAS_ANALYSIS_TYPE ${VERITAS_ANALYSIS_TYPE}" >> ${MSCWLOGFILE}

# move logfiles into output file
if [[ -e ${MSCWLOGFILE} ]]; then
  cp -v ${MSCWLOGFILE} $TEMPDIR/
  LLF="${TEMPDIR}/$(basename ${MSCWLOGFILE})"
  $EVNDISPSYS/bin/logFile mscwTableLog "$TEMPDIR/$BFILE.mscw.root" "$LLF"
fi

# move output file from scratch and clean up
cp -f -v $TEMPDIR/$BFILE.mscw.root $MSCWDATAFILE
rm -f $TEMPDIR/$BFILE.mscw.root
rm -f $TEMPDIR/$BFILE.root

# write info to log
echo "RUN$BFILE MSCWLOG ${MSCWLOGFILE}"
echo "RUN$BFILE MSCWDATA $MSCWDATAFILE"

# remove files in TEMPDIR
rm -rf $TEMPDIR

exit
