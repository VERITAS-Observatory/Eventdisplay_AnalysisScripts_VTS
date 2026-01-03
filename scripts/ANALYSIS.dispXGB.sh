#!/bin/bash
# XGBoost analysis on mscw data files.

# qsub parameters
h_cpu=11:59:00; h_vmem=4000M; tmpdir_size=25G

if [ "$#" -lt 3 ]; then
echo "
Run XGBoost disp reconstruction on mscw files

ANALYSIS.dispXGB.sh <analysis type> <run list> <output directory>

required parameters:

    <analysis type>         analysis type - 'stereo_analysis' or 'classification'

    <runlist>               simple run list with one run number per line.

    <output directory>      directory where fits.gz files are written
"
exit
fi
# Parse command line arguments
XGB_TYPE=$1
RUNLIST=$2
[[ "$3" ]] && ODIR=$3
XGB="xgb"
ANALYSIS_TYPE="${VERITAS_ANALYSIS_TYPE:0:2}"

echo "XGB analysis type: $XGB_TYPE"

# Read run list
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, runlist $RUNLIST not found, exiting..."
    exit 1
fi
FILES=$(cat "$RUNLIST")

NRUNS=$(cat "$RUNLIST" | wc -l)
echo "total number of runs to analyze: $NRUNS"

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/XGB-${XGB_TYPE}-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f ${LOGDIR}/x* 2>/dev/null

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.dispXGB_sub"
TIMETAG=`date +"%s"`

for RUNN in $FILES
do
    echo "Now analysing run $RUNN"
    FSCRIPT="$LOGDIR/dispXGB-${XGB_TYPE}-$RUNN"
    rm -f $FSCRIPT.sh

    sed -e "s|RRUN|$RUNN|" \
        -e "s|XXGB|$XGB|" \
        -e "s|XGB_TTYPE|$XGB_TYPE|" \
        -e "s|ANALYSISTYPE|$ANALYSIS_TYPE|" \
        -e "s|OODIR|$ODIR|" $SUBSCRIPT.sh > $FSCRIPT.sh

    chmod u+x "$FSCRIPT.sh"
    echo $FSCRIPT.sh

    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    if [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs at once:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
    elif [[ $SUBC == *sbatch* ]]; then
        $SUBC $FSCRIPT.sh
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> ${LOGDIR}/runscripts.$TIMETAG.dat
        echo "RUN $RUNN OLOG $FSCRIPT.log"
    elif [[ "$SUBC" == *simple* ]] ; then
       "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
    fi
done
