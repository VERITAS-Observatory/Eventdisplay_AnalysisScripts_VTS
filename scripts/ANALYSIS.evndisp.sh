#!/bin/bash
# script to run eventdisplay analysis for VTS data

# qsub parameters
h_cpu=11:59:00; h_vmem=2000M; tmpdir_size=25G

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/evndisp --version | tr -d .`

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
# begin help message
echo "
EVNDISP data analysis: submit jobs from a simple run list

ANALYSIS.evndisp.sh <runlist> [output directory] [runparameter file] [calibration] [teltoana] [calibration file name]

required parameters:

    <runlist>               simple run list with one run number per line
    
optional parameters:
    
    [output directory]     directory where output ROOT files will be stored.
			   Default: $VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/

None of the following options are usually required:
	 
    [runparameter file]    file with integration window size and reconstruction cuts/methods,
                           expected in $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/

			               Default: EVNDISP.reconstruction.runparameter.v4x
                           (for v5x versions: EVNDISP.reconstruction.runparameter)

    [calibration]	   
          0		   neither tzero nor pedestal calculation is performed, must have the calibration results
			   already in $VERITAS_EVENTDISPLAY_AUX_DIR/Calibration/Tel_?
          1                pedestal & average tzero calculation (default)
          2                pedestal calculation only
          3                average tzero calculation only
          4                pedestal & average tzero calculation are performed;
                           laser run number is taken from calibration file,
                           gains taken from $VERITAS_EVENTDISPLAY_AUX_DIR/Calibration/Tel_?/<laserrun>.gain.root 


    [teltoana]             restrict telescope combination to be analyzed:
                           e.g.: teltoana=123 (for tel. 1,2,3), 234, ...
                           Default is to use the telescope combination from the DB. Telescopes that were not in the array
			   or have been cut by DQM are not analysed.

    [calibration file name] only used with calibration=4 option
			   to specify a which runs should be used for pedestal/tzero/gain calibration.
                           Default is calibrationlist.dat
                           file is expected in $VERITAS_EVNDISP_AUX_DIR/Calibration

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# create extra stdout for duplication of command output
# look for ">&5" below
exec 5>&1

# Parse command line arguments
RLIST=$1
[[ "$2" ]] && ODIR=$2 || ODIR="$VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/"
mkdir -p $ODIR
ACUTS_AUTO="EVNDISP.reconstruction.runparameter"
if [[ $EDVERSION = "v4"* ]]; then
   ACUTS_AUTO="EVNDISP.reconstruction.runparameter.v4x"
fi
[[ "$3" ]] && ACUTS=$3 || ACUTS=${ACUTS_AUTO}
[[ "$4" ]] && CALIB=$4 || CALIB=1
[[ "$5" ]] && TELTOANA=$5 || TELTOANA=1234
[[ "$6" ]] && CALIBFILE=$6 || CALIBFILE=calibrationlist.dat
# VPM is on by default
VPM=1
# Download file to disk (if not available)
DOWNLOAD=0
# directory with DB text
DBTEXTDIRECTORY="${VERITAS_DATA_DIR}/DBTEXT"

echo "Using runparameter file $ACUTS ($EDVERSION)"

# Read runlist
if [ ! -f "$RLIST" ] ; then
    echo "Error, runlist $RLIST not found, exiting..."
    exit 1
fi
FILES=`cat "$RLIST"`

# Output directory for error/output
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/EVNDISP.ANADATA"
mkdir -p "$LOGDIR"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.evndisp_sub"
# run locally or on cluster
SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`

# time tag used in script naming
TIMETAG=`date +"%s"`
TIMESUFF="-$(date +%s)"
if [[ $SUBC == *parallel* ]]; then
   TIMESUFF=""
   touch $LOGDIR/runscripts.sh
fi

NRUNS=`cat "$RLIST" | wc -l ` 
echo "total number of runs to analyze: $NRUNS"
echo

# sleep required for large data sets to avoid overload
# of database and many jobs running in parallel
SLEEPABIT="1s"
if [ "$NRUNS" -gt "50" ] ; then
   SLEEPABIT="30s"
   echo "Long list of runs (${NRUNS}), will sleep after each run for ${SLEEPABIT}"
fi

#################################
# low gain calibration file
mkdir -p ${ODIR}/Calibration/
if [[ -e "${VERITAS_EVNDISP_AUX_DIR}/Calibration/calibrationlist.LowGain.dat" ]]; then
   cp -f -v ${VERITAS_EVNDISP_AUX_DIR}/Calibration/calibrationlist.LowGain.dat ${ODIR}/Calibration/
else
   echo "error - low-gain calibration list not found (${VERITAS_EVNDISP_AUX_DIR}/Calibration/calibrationlist.LowGain.dat)"
   exit
fi
if [[ -e "${VERITAS_EVNDISP_AUX_DIR}/Calibration/LowGainPedestals.lped" ]]; then
   cp -f -v ${VERITAS_EVNDISP_AUX_DIR}/Calibration/LowGainPedestals.lped ${ODIR}/Calibration/
else
   echo "error - low-gain calibration list not found (${VERITAS_EVNDISP_AUX_DIR}/Calibration/LowGainPedestals.lped)"
   exit
fi

#########################################
# loop over all files in files loop
for AFILE in $FILES
do
    echo "Now starting run $AFILE"
    FSCRIPT="$LOGDIR/EVN.data-${AFILE}${TIMESUFF}"

    if [[ -d ${DBTEXTDIRECTORY}/$AFILE ]]; then
        DBTEXTDIR="${DBTEXTDIRECTORY}"
    else
        DBTEXTDIR="0"
    fi

    sed -e "s|RUNFILE|$AFILE|"              \
        -e "s|CALIBRATIONOPTION|$CALIB|"    \
        -e "s|OUTPUTDIRECTORY|$ODIR|"       \
        -e "s|USEVPMPOINTING|$VPM|" \
        -e "s|RECONSTRUCTIONRUNPARAMETERFILE|$ACUTS|" \
        -e "s|TELTOANACOMB|$TELTOANA|"                   \
        -e "s|VVERSION|$EDVERSION|" \
        -e "s|DOWNLOADVBF|$DOWNLOAD|" \
        -e "s|DATABASETEXT|${DBTEXTDIR}|" \
        -e "s|USECALIBLIST|$CALIBFILE|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"

    chmod u+x "$FSCRIPT.sh"
    echo "$FSCRIPT.sh"

    # output selected input during submission:

    echo "Using runparameter file ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/$ACUTS"

    if [[ $VPM == "1" ]]; then
        echo "VPM is switched on (default)"
    else
        echo "VPM bool is set to $VPM (switched off)"
    fi  

    if [[ $TELTOANA == "1234" ]]; then
	echo "Telescope combination saved in the DB is analyzed (default)"
    else
	echo "Analyzed telescopes: $TELTOANA"
    fi 
    if [[ $CALIB == "4" ]]; then
            echo "read calibration from calibration file $CALIBFILE"
    else
            echo "read calibration from VOffline DB (default)"
    fi 

    if [[ $SUBC == *qsub* ]]; then
        JOBID=`$SUBC $FSCRIPT.sh`
        # account for -terse changing the job number format
        if [[ $SUBC != *-terse* ]] ; then
            echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
            JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
        fi
        
        echo "RUN $AFILE JOBID $JOBID"
        echo "RUN $AFILE SCRIPT $FSCRIPT.sh"
        if [[ $SUBC != */dev/null* ]] ; then
            echo "RUN $AFILE OLOG $FSCRIPT.sh.o$JOBID"
            echo "RUN $AFILE ELOG $FSCRIPT.sh.e$JOBID"
        fi
    elif [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
        condor_submit $FSCRIPT.sh.condor
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh" >> $LOGDIR/runscripts.sh
        echo "RUN $AFILE OLOG $FSCRIPT.log"
    elif [[ "$SUBC" == *simple* ]] ; then
	"$FSCRIPT.sh" |& tee "$FSCRIPT.log"	
    fi

    if [[ ! -d ${DBTEXTDIRECTORY}/$AFILE ]]; then
        sleep ${SLEEPABIT}
    fi
done

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    echo
    echo "$LOGDIR/runscripts.sh"
    echo
    chmod +x $LOGDIR/runscripts.sh
    echo "echo \"==================================\"" >> Run_me.sh
    echo "echo \"List of scripts to run\"" >> Run_me.sh
    cat $LOGDIR/runscripts.sh | sort -u | awk "{print \$1}" | sed 's/.*/echo \" & \"/' >> Run_me.sh
    echo "cat $LOGDIR/runscripts.sh | sort -u | $SUBC" >> Run_me.sh
    chmod +x Run_me.sh
    source Run_me.sh
    rm Run_me.sh
fi

