#!/bin/bash
# script to analyse VTS raw files (VBF) with eventdisplay

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

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
DOWNLOAD=DOWNLOADVBF
DBTEXTDIRECTORY=DATABASETEXT

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$RUN
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

#################################
echo "Using run parameter file $ACUTS"

#################################
# check if run is on disk
RUNONDISK=$(echo $RUN | $EVNDISPSCRIPTS/RUNLIST.whichRunsAreOnDisk.sh -d)
if [[ ${RUNONDISK} == *"file not found"** ]]; then
  echo "$RUN not on disk"
  if [[ $DOWNLOAD == "0" ]]; then
      touch "$LOGDIR/$RUN.NOTONDISK"
      exit
  fi
else
    rm -f "$LOGDIR/$RUN.NOTONDISK"
fi

#################################
# Download raw data (vbf) file
# (note that download is not working on DESY cluster)
# 1 = download to tmp disk (remove vbf file after analysis)
# 2 = download to $VERITAS_DATA_DIR (keep vbf file after analysis)
if [[ $DOWNLOAD == "1" ]] || [[ $DOWNLOAD == "2" ]]; then
   # check that bbftp exists
   BBFTP=$(which bbftp)
   if [[ $BBFTP == *"not found"* ]]; then
        echo "error: bbftp not installed; exiting"
        exit
   fi
   if [[ ! -e $EVNDISPSCRIPTS/RUNLIST.whichRunsAreOnDisk.sh ]]; then
        echo "error: $EVNDISPSCRIPTS/RUNLIST.whichRunsAreOnDisk.sh script not installed; exiting"
        exit
   fi
   # check if run is on disk
   RUNONDISK=$(echo $RUN | $EVNDISPSCRIPTS/RUNLIST.whichRunsAreOnDisk.sh -d)
   if [[ ${RUNONDISK} == *"file not found"** ]]; then
      echo "$RUN not on disk; try downloading to $TEMPDIR"
      if [[ $DOWNLOAD == "1" ]]; then
          VERITAS_DATA_DIR=${TEMPDIR}
      fi
      RAWDATE=$(echo $RUNONDISK | awk '{print $NF}')
      VTSRAWDATA=$(grep VTSRAWDATA $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/EVNDISP.global.runparameter | grep "*" | awk '{print $NF}')
      echo "DOWNLOAD FILE $VERITAS_DATA_DIR/d$RAWDATE/$RUN.cvbf"
      ${BBFTP} -V -S -p 4 -u bbftp -e "get /veritas/data/d$RAWDATE/$RUN.cvbf $VERITAS_DATA_DIR/d$RAWDATE/$RUN.cvbf" $VTSRAWDATA
   else
        DOWNLOAD="0"
   fi
   echo "DOWNLOAD STATUS $DOWNLOAD"
fi

if [[ ! "${DBTEXTDIRECTORY}" -eq "0" ]]; then
    OPT=( -dbtextdirectory ${DBTEXTDIRECTORY} )
fi
        
#########################################
# pedestal calculation
if [[ $CALIB == "1" || ( $CALIB == "2" || $CALIB == "4" ) ]]; then
    rm -f $LOGDIR/$RUN.ped.log
    echo "AAA ${OPT[@]}"
    $EVNDISPSYS/bin/evndisp \
        -runmode=1 -runnumber="$RUN" \
        -reconstructionparameter "$ACUTS" \
        "${OPT[@]}" \
        -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.ped.log"
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
if [[ $CALIB == "1" || ( $CALIB == "3" || $CALIB == "4" ) ]]; then
    rm -f $LOGDIR/$RUN.tzero.log
    $EVNDISPSYS/bin/evndisp \
        -runnumber=$RUN -runmode=7 \
        -calibrationsummin=50 \
        -reconstructionparameter "$ACUTS" \
        "${OPT[@]}" \
        -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.tzero.log" 
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
# OPT+=( -writeimagepixellist )

#########################################
# run eventdisplay
LOGFILE="$LOGDIR/$RUN.log"
rm -f "$LOGDIR/$RUN.log"
$EVNDISPSYS/bin/evndisp \
    -runnumber="$RUN" \
    -reconstructionparameter "$ACUTS" \
    -outputfile "$TEMPDIR/$RUN.root" \
    "${OPT[@]}" \
    -calibrationdirectory "$CALDIR" &> "$LOGFILE"
# DST $EVNDISPSYS/bin/evndisp -runnumber=$RUN -nevents=250000 -runmode=4 -readcalibdb -dstfile $TEMPDIR/$RUN.dst.root -reconstructionparameter $ACUTS -outputfile $TEMPDIR/$RUN.root ${OPT[@]} &> "$LOGFILE"
echo "RUN$RUN EVNDISPLOG $LOGFILE"

# move data file from tmp dir to data dir
DATAFILE="$ODIR/$RUN.root"
cp -f -v "$TEMPDIR/$RUN.root" "$DATAFILE"
if [[ -f "$TEMPDIR/$RUN.IPR.root" ]]; then
    cp -f -v "$TEMPDIR/$RUN.IPR.root" "$ODIR/$RUN.IPR.root"
fi
echo "RUN$RUN VERITAS_USER_DATA_DIR $DATAFILE"
rm -f "$TEMPDIR/$RUN.root"
# DST cp -f -v $TEMPDIR/$RUN.dst.root $DATAFILE

########################################
# cleanup raw data (if downloaded)
if [[ $DOWNLOAD == "1" ]]; then
   rm -f -v $VERITAS_DATA_DIR/d$RAWDATE/$RUN.cvbf
fi

exit
