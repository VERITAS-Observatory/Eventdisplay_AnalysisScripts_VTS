#!/bin/bash
# script to analyse VTS raw files (VBF) with eventdisplay

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source $EVNDISPSYS/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
RUN=RUNFILE
CALIB=CALIBRATIONOPTION
ODIR=OUTPUTDIRECTORY
VPM=USEVPMPOINTING
CALIBFILE=USECALIBLIST
TELTOANA=TELTOANACOMB
LOGDIR="$ODIR"
CALDIR="$ODIR"
ACUTS=RECONSTRUCTIONRUNPARAMETERFILE
EDVERSION=VVERSION
DBTEXTDIRECTORY=DATABASETEXT
VERITAS_DATA_DIR=VTS_DATA_DIR
VERITAS_DATA_DIR_2=VTS_2DATA_DIR
VERITAS_USER_DATA_DIR=VTS_USER_DATA_DIR
#
# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$RUN
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${VERITAS_DATA_DIR_2}:/opt/VERITAS_DATA_DIR_2 "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${DBTEXTDIRECTORY}:/opt/DBTEXT "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${TEMPDIR}:/opt/TEMPDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_DATA_DIR=/opt/VERITAS_DATA_DIR,VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,TEMPDIR=/opt/TEMPDIR,CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be reset
    CALDIR="/opt/ODIR"
fi

#################################
echo "Using run parameter file $ACUTS"

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

unpack_db_textdirectory()
{
    RRUN=${1}
    TMP_DBTEXTDIRECTORY=${2}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    DBRUNFIL="${DBTEXTDIRECTORY}/${SRUN}/${RRUN}.tar.gz"
    echo "DBTEXT FILE for $RRUN $DBRUNFIL" >&2
    if [[ -e ${DBRUNFIL} ]]; then
        mkdir -p ${TMP_DBTEXTDIRECTORY}/${SRUN}
        tar -xzf ${DBRUNFIL} -C ${TMP_DBTEXTDIRECTORY}/${SRUN}/
    else
        echo "DBTEXT FILE not found ($DBRUNFIL)" >&2
    fi
    echo "${TMP_DBTEXTDIRECTORY}/${SRUN}/${RRUN}/${RRUN}.laserrun"
}

sub_dir()
{
    TDIR="$1"
    TRUN="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        echo "${TDIR}/${TRUN:0:1}/"
    else
        echo "${TDIR}/${TRUN:0:2}/"
    fi
}


# Unpack DBText information (replacement to DB calls)
if [[ "${DBTEXTDIRECTORY}" != "0" ]]; then
    echo "UNPACKING DBTEXT from ${DBTEXTDIRECTORY}"
    ls -l ${DBTEXTDIRECTORY}
    TMP_DBTEXTDIRECTORY="${TEMPDIR}/DBTEXT"
    TMP_LASERRUN=$(unpack_db_textdirectory $RUN $TMP_DBTEXTDIRECTORY)
    LRUNID=$(cat ${TMP_LASERRUN} | grep -v run_id | awk -F "|" '{print $1}')
    for LL in ${LRUNID}
    do
        echo "unpacking $LL"
        unpack_db_textdirectory $LL $TMP_DBTEXTDIRECTORY
    done
    echo "DBTEXT directory $(ls -l $TMP_DBTEXTDIRECTORY)"

    OPT=( -dbtextdirectory ${TMP_DBTEXTDIRECTORY} -epochfile VERITAS.Epochs.runparameter )
    echo "${OPT[@]}"
fi

get_run_date()
{
    OFIL="$1"
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ ));
            do
                if [[ ${a[$j]} == "data_start_time" ]]; then
                    start_time_index=$j
                    break;
                fi
            done
        fi
        start_time="${a[$start_time_index]}"
    done < ${OFIL}
    year=$(date -d "$start_time" +%Y)
    month=$(date -d "$start_time" +%m)
    day=$(date -d "$start_time" +%d)
    echo "d${year}${month}${day}"
}


#################################
# check if run is on disk
if [[ "${DBTEXTDIRECTORY}" != "0" ]]; then
    RUNINFO=$(sub_dir ${TMP_DBTEXTDIRECTORY} ${RUN})/${RUN}/${RUN}.runinfo
    RUNDATE=$(get_run_date ${RUNINFO})
    echo "RUN $RUN $RUNINFO $RUNDATE"
    ls -l ${TMP_DBTEXTDIRECTORY}
    if [[ ! -e ${VERITAS_DATA_DIR}/data/${RUNDATE}/${RUN}.cvbf ]]; then
        # TMP for preprocessing
        if [[ ! -e ${VERITAS_DATA_DIR_2}/data/data/${RUNDATE}/${RUN}.cvbf ]]; then
            RUNONDISK="file not found"
        else
            if [ -n "$EVNDISP_APPTAINER" ]; then
                OPT+=( -sourcefile /opt/VERITAS_DATA_DIR_2/data/data/${RUNDATE}/${RUN}.cvbf )
            else
                OPT+=( -sourcefile ${VERITAS_DATA_DIR_2}/data/data/${RUNDATE}/${RUN}.cvbf )
            fi
        fi
        # END TMP
    fi
else
    # original way accessing the VERITAS DB
    RUNONDISK=$(echo $RUN | $EVNDISPSCRIPTS/RUNLIST.whichRunsAreOnDisk.sh -d)
fi
if [[ ${RUNONDISK} == *"file not found"** ]]; then
  echo "$RUN not on disk"
  touch "$LOGDIR/$RUN.NOTONDISK"
  exit
else
  rm -f "$LOGDIR/$RUN.NOTONDISK"
fi

echo "CVBF FILE FOUND - data dir: $VERITAS_DATA_DIR"

#########################################
# pedestal calculation
if [[ $CALIB == "1" || $CALIB == "2" || $CALIB == "4" || $CALIB == "5" ]]; then
    rm -f $LOGDIR/$RUN.ped.log
    $EVNDISPSYS/bin/evndisp \
        -runmode=1 -runnumber="$RUN" \
        -reconstructionparameter "$ACUTS" \
        "${OPT[@]}" \
        -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.ped.log"
    echo "$(inspect_executables)" >> "$LOGDIR/$RUN.ped.log"
    echo "RUN$RUN PEDLOG $LOGDIR/$RUN.ped.log"
fi

#########################################

## use text file for calibration information
if [[ $CALIB == "4" ]]; then
## use text file for calibration information
	OPT+=( -calibrationfile $CALIBFILE )
else
## read gain and toffsets from VOFFLINE DB (default)
	OPT+=( "-readCalibDB" )
fi

# restrict telescope combination to be analyzed:
if [[ $TELTOANA == "1234" ]]; then
	echo "Telescope combination saved in the DB is analyzed (default)"
else
	OPT+=( -teltoana=$TELTOANA )
	echo "Analyzed telescope configuration: $TELTOANA "
fi

# None of the following command line options is needed for the standard analysis!

## Read gain and toff from VOFFLINE DB requiring a special version of analysis
# OPT+=( -readCalibDB version_number )
## Warning: this version must already exist in the DB

## Read gain and toff from VOFFLINE DB and save the results in the directory
## where the calib file should be (it won't erase what is already there)
# OPT+=( -readandsavecalibdb )

#########################################
# average tzero calculation
if [[ $CALIB == "1" || $CALIB == "3" || $CALIB == "4" || $CALIB == "5" ]]; then
    rm -f $LOGDIR/$RUN.tzero.log
    $EVNDISPSYS/bin/evndisp \
        -runnumber=$RUN -runmode=7 \
        -calibrationsummin=50 \
        -reconstructionparameter "$ACUTS" \
        "${OPT[@]}" \
        -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.tzero.log"
    echo "$(inspect_executables)" >> "$LOGDIR/$RUN.tzero.log"
    echo "RUN$RUN TZEROLOG $LOGDIR/$RUN.tzero.log"
fi

#########################################
# Command line options for pointing and calibration

# pointing from pointing monitor (DB)
if [[ $VPM == "1" ]]; then
    OPT+=( -usedbvpm )
fi

## pointing from db using T-point correction from 2007-11-05
# OPT+=( -useDBtracking -useTCorrectionfrom "2007-11-05" )
#
## OFF data run
# OPT+=( -raoffset=6.25 )

## double pass correction
# OPT+=( -nodp2005 )

# write image pixel list (increase file size by 40%)
# OPT+=( -writeimagepixellist )

#########################################
# run eventdisplay
if [[ $CALIB != "5" ]]; then
LOGFILE="$LOGDIR/$RUN.log"
    rm -f "$LOGDIR/$RUN.log"
    $EVNDISPSYS/bin/evndisp \
        -runnumber="$RUN" \
        -reconstructionparameter "$ACUTS" \
        -outputfile "$TEMPDIR/$RUN.root" \
        "${OPT[@]}" \
        -calibrationdirectory "$CALDIR" &> "$LOGFILE"
    echo "$(inspect_executables)" >> "$LOGFILE"
    echo "RUN$RUN EVNDISPLOG $LOGFILE"
fi

# move log file into root file
if [[ -e "$LOGFILE" ]]; then
    cp -v $LOGFILE $TEMPDIR
    LLF="${TEMPDIR}/$RUN.log"
    $EVNDISPSYS/bin/logFile evndispLog "$TEMPDIR/$RUN.root" "$LLF"
fi
if [[ -e "$LOGDIR/$RUN.ped.log" ]]; then
    cp -v $LOGDIR/$RUN.ped.log $TEMPDIR
    LLF="${TEMPDIR}/$RUN.ped.log"
    $EVNDISPSYS/bin/logFile evndisppedLog "$TEMPDIR/$RUN.root" "$LLF"
fi
if [[ -e "$LOGDIR/$RUN.tzero.log" ]]; then
    cp -v $LOGDIR/$RUN.tzero.log $TEMPDIR
    LLF="${TEMPDIR}/$RUN.tzero.log"
    $EVNDISPSYS/bin/logFile evndisptzeroLog "$TEMPDIR/$RUN.root" "$LLF"
fi

# move data file from tmp dir to data dir
if [[ $CALIB != "5" ]]; then
    DATAFILE="$ODIR/$RUN.root"
    cp -f -v "$TEMPDIR/$RUN.root" "$DATAFILE"
    if [[ -f "$TEMPDIR/$RUN.IPR.root" ]]; then
        cp -f -v "$TEMPDIR/$RUN.IPR.root" "$ODIR/$RUN.IPR.root"
    fi
    echo "RUN$RUN VERITAS_USER_DATA_DIR $DATAFILE"
    rm -f "$TEMPDIR/$RUN.root"
fi

exit
