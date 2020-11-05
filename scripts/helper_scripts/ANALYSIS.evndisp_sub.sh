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
# low gain calibration file
if [[ -e "$VERITAS_EVNDISP_AUX_DIR/Calibration/calibrationlist.LowGain.dat" ]]; then
   cp -f -v $VERITAS_EVNDISP_AUX_DIR/Calibration/calibrationlist.LowGain.dat $CALDIR/Calibration/
else
   echo "error - low-gain calibration list not found ($VERITAS_EVNDISP_AUX_DIR/Calibration/calibrationlist.LowGain.dat)"
   exit
fi
if [[ -e "$VERITAS_EVNDISP_AUX_DIR/Calibration/LowGainPedestals.lped" ]]; then
   cp -f -v $VERITAS_EVNDISP_AUX_DIR/Calibration/LowGainPedestals.lped $CALDIR/Calibration/
else
   echo "error - low-gain calibration list not found ($VERITAS_EVNDISP_AUX_DIR/Calibration/LowGainPedestals.lped)"
   exit
fi

#########################################
# pedestal calculation
if [[ $CALIB == "1" || ( $CALIB == "2" || $CALIB == "4" ) ]]; then
    rm -f $LOGDIR/$RUN.ped.log
    $EVNDISPSYS/bin/evndisp -runmode=1 -runnumber="$RUN" -reconstructionparameter "$ACUTS" -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.ped.log"
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
# v485    $EVNDISPSYS/bin/evndisp -runnumber=$RUN -runmode=7 -reconstructionparameter $ACUTS ${OPT[@]} &> $LOGDIR/$RUN.tzero.log 
    if [[ $EDVERSION = "v4"* ]]; then
        $EVNDISPSYS/bin/evndisp -runnumber=$RUN -runmode=7 -calibrationsummin=50 -reconstructionparameter "$ACUTS" "${OPT[@]}" -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.tzero.log" 
    else
        $EVNDISPSYS/bin/evndisp -runnumber=$RUN -runmode=7 -sumwindowaveragetime=6 -calibrationsummin=50 -reconstructionparameter "$ACUTS" "${OPT[@]}" -calibrationdirectory "$CALDIR" &> "$LOGDIR/$RUN.tzero.log" 
    fi
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

#########################################
# run eventdisplay
LOGFILE="$LOGDIR/$RUN.log"
rm -f "$LOGDIR/$RUN.log"
# v48x $EVNDISPSYS/bin/evndisp -runnumber=$RUN -reconstructionparameter $ACUTS -outputfile $TEMPDIR/$RUN.root ${OPT[@]} &> "$LOGFILE"
$EVNDISPSYS/bin/evndisp -runnumber="$RUN" -reconstructionparameter "$ACUTS" -outputfile "$TEMPDIR/$RUN.root" "${OPT[@]}" -calibrationdirectory "$CALDIR" &> "$LOGFILE"
# DST $EVNDISPSYS/bin/evndisp -runnumber=$RUN -nevents=250000 -runmode=4 -readcalibdb -dstfile $TEMPDIR/$RUN.dst.root -reconstructionparameter $ACUTS -outputfile $TEMPDIR/$RUN.root ${OPT[@]} &> "$LOGFILE"
echo "RUN$RUN EVNDISPLOG $LOGFILE"

# move data file from tmp dir to data dir
DATAFILE="$ODIR/$RUN.root"
cp -f -v "$TEMPDIR/$RUN.root" "$DATAFILE"
echo "RUN$RUN VERITAS_USER_DATA_DIR $DATAFILE"
rm -f "$TEMPDIR/$RUN.root"
# DST cp -f -v $TEMPDIR/$RUN.dst.root $DATAFILE

exit
