#!/bin/bash
# submit XGBoost analyse on mscw MC files.

# qsub parameters
h_cpu=11:59:00; h_vmem=8000M; tmpdir_size=25G

if [ "$#" -lt 4 ]; then
echo "
Run XGBoost disp reconstruction on mscw files

IRF.dispXGB.sh <input file directory> <output directory> <XGB>

required parameters:

    <analysis type>         analysis type - 'stereo_analysis' or 'classification'
    <input file directory>  directory with input files (will use all *.mscw.root files)

    <output directory>      directory where fits.gz files are written

    <XGB>                   XGB model name (e.g. v7_noWeight_DirXGB_0.5_1000000)
"
exit
fi
# set -e
# Parse command line arguments
XGB_TYPE=$1
INPUTDIR=$2
[[ "$2" ]] && ODIR=$3
[[ "$3" ]] && XGB=$4
ANALYSIS_TYPE="${VERITAS_ANALYSIS_TYPE:0:2}"

echo "XGB analysis type: $XGB_TYPE"

# Read file list
if [[ ! -d "$INPUTDIR" ]]; then
    echo "Error, input directory $INPUTDIR not found, exiting..."
    exit 1
fi
FILES=$(find "$INPUTDIR" -name "*.mscw.root" | sort -u | head -n 1)

NFILES=$(find "$INPUTDIR" -name "*.mscw.root" | wc -l)
if [ "$NFILES" -gt 0 ]; then
    echo "total number of files to analyze: $NFILES"
else
    echo "Error, no input files found in $INPUTDIR"
    exit 1
fi

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$(dirname $INPUTDIR)/submit-XGB-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f ${LOGDIR}/x* 2>/dev/null

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.dispXGB_sub"
TIMETAG=`date +"%s"`

for FILE in $FILES
do
    echo "Now analysing $FILE"
    FSCRIPT="$LOGDIR/dispXGB-$(basename $FILE .root)"
    rm -f $FSCRIPT.sh

    sed -e "s|FFILE|$FILE|" \
        -e "s|XXGB|$XGB|" \
        -e "s|XGB_TTYPE|$XGB_TTYPE|" \
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
    elif [[ "$SUBC" == *simple* ]] ; then
       "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
    fi
done
