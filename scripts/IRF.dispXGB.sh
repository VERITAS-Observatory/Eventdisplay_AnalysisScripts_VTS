#!/bin/bash
# script to run XGBoost on mscw MCfiles.
#

# qsub parameters
h_cpu=11:59:00; h_vmem=8000M; tmpdir_size=25G

if [ "$#" -lt 2 ]; then
echo "
Run XGBoost disp reconstruction on mscw files

IRF.dispXGB.sh <input file list> <output directory> <XGB>

required parameters:

    <input file list>       file list of input files with one file per line

    <output directory>      directory where fits.gz files are written

    <XGB>                   XGB model name (e.g. v7_noWeight_DirXGB_0.5_1000000)
"
exit
fi
# Parse command line arguments
FILELIST=$1
[[ "$2" ]] && ODIR=$2
[[ "$3" ]] && XGB=$3

# Read file list
if [[ ! -f "$FILELIST" ]]; then
    echo "Error, file list $FILELIST not found, exiting..."
    exit 1
fi
FILES=$(cat "$FILELIST")

NFILES=$(cat "$FILELIST" | wc -l)
echo "total number of files to analyze: $NFILES"

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/XGB-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f ${LOGIDR}/x* 2>/dev/null

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
