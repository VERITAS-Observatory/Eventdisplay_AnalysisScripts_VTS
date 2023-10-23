#!/bin/bash
# script to run V2DL3 
# (convert anasum output to FITS-DL3)
# run point-like and full-enclosure analysis
#

# qsub parameters
h_cpu=11:59:00; h_vmem=4000M; tmpdir_size=5G

# EventDisplay version
EDVERSION=$($EVNDISPSYS/bin/anasum --version | tr -d .)
# Directory with preprocessed data
DEFANASUMDIR="$VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/anasum/"
V2DL3="$EVNDISPSYS/../V2DL3/"

if [ $# -lt 3 ]; then
echo "
Convert anasum to FITS-DL3

ANALYSIS.v2dl3.sh <run list> <output directory> <cut name> [nruns per job]

required parameters:

    <runlist>               simple run list with one run number per line.
    
    <output directory>      directory where fits.gz files are written

    <cut name>              cut name to search pre-processing directories

    [nruns per job]        number of runs per job (default: 100)

Expect installation of V2DL3 (https://github.com/VERITAS-Observatory/V2DL3) and
corresponding conda installation (v2dl3Eventdisplay)

"
exit
fi
# Parse command line arguments
RLIST=$1
ODIR=$2
CUT=$3
[[ "$4" ]] && SPLITRUN=$4 || SPLITRUN=100

# Read runlist
if [ ! -f "$RLIST" ] ; then
    echo "Error, runlist $RLIST not found, exiting..."
    exit 1
fi

NRUNS=$(cat "$RLIST" | wc -l)
echo "total number of runs to analyze: $NRUNS"
echo

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# run scripts are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/V2DL3-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f ${LOGIDR}/x* 2>/dev/null

# split run list into smaller run lists
cp -f ${RLIST} ${LOGDIR}/
(cd "${LOGDIR}" && split -l $SPLITRUN "${LOGDIR}/$(basename ${RLIST})")

FILELISTS=$(ls ${LOGDIR}/x*)
NFILELISTS=$(ls ${LOGDIR}/x* | wc -l)

echo -e "Processing $NFILELISTS file lists (equal to number of jobs)"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.v2dl3_sub"
TIMETAG=`date +"%s"`

for J in ${FILELISTS}
do
    echo "Submitting analysis for file list $J"

    FSCRIPT="${LOGDIR}/V2DL3-$(basename $J)"
    rm -f $FSCRIPT.sh

    sed -e "s|RRUNLIST|$J|" \
        -e "s|OODIR|$ODIR|" \
        -e "s|CCUT|$CUT|" $SUBSCRIPT.sh > $FSCRIPT.sh

    chmod u+x $FSCRIPT.sh

    # run locally or on cluster
    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    echo "Submission command: $SUBC"
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
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs at once:"
        echo "./helper_scripts/submit_scripts_to_htcondor.sh $LOGDIR submit"
        echo "-------------------------------------------------------------------------------"
        echo
    elif [[ $SUBC == *sbatch* ]]; then
        $SUBC $FSCRIPT.sh   
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> ${LOGDIR}/runscripts.$TIMETAG.dat
        echo "RUN $AFILE OLOG $FSCRIPT.log"
    elif [[ "$SUBC" == *simple* ]] ; then
        "$FSCRIPT.sh" |& tee "$FSCRIPT.log"	
    fi
done

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    cat $LOGDIR/runscripts.$TIMETAG.dat | $SUBC
fi
