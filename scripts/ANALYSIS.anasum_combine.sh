#!/bin/bash
# script to combine anasum files processed in parallel mode

# qsub parameters
h_cpu=0:59:00; h_vmem=4000M; tmpdir_size=1G

if [[ $# -lt 3 ]]; then
# begin help message
echo "
ANASUM parallel data analysis: combine parallel-processed anasum runs

ANALYSIS.anasum_combine.sh <anasum run list> <anasum directory> <output file name> [run parameter file]

required parameters:

    <anasum run list>       full anasum run list
                            (with effective areas, file names, etc.)
        
    <anasum directory>      input directory containing anasum root files
        
    <output file name>      name of combined anasum file
                            (written to same location as anasum files)
        
optional parameters:

    [run parameter file]    anasum run parameter file (located in 
                            \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/;
                            default is ANASUM.runparameter)

IMPORTANT! Run only after all ANALYSIS.anasum_parallel.sh jobs have finished!

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RUNLIST=$1
DDIR=$2
OUTFILE=$3
OUTFILE=${OUTFILE%%.root}
[[ "$4" ]] && RUNP=$4 || RUNP="ANASUM.runparameter"

# Check that run list exists
if [ ! -f "$RUNLIST" ]; then
    echo "Error, anasum runlist $RUNLIST not found, exiting..."
    exit 1
fi

# Check that run parameter file exists
if [[ "$RUNP" == `basename $RUNP` ]]; then
    RUNP="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNP"
fi
if [[ ! -f "$RUNP" ]]; then
    echo "Error, anasum run parameter file '$RUNP' not found, exiting..."
    exit 1
fi

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/submit.ANASUM.ANADATA-${DATE}-$(uuidgen)"
mkdir -p "$LOGDIR"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.anasum_combine_sub"

FSCRIPT="$LOGDIR/anasum_combine-$DATE-RUN$RUN-$(date +%s)"
echo "Run script written to $FSCRIPT"

sed -e "s|RRUNLIST|$RUNLIST|" \
    -e "s|DDDIR|$DDIR|" \
    -e "s|RRUNP|$RUNP|" \
    -e "s|OOUTFILE|$OUTFILE|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"
chmod u+x "$FSCRIPT.sh"

# run locally or on cluster
SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
if [[ $SUBC == *qsub* ]]; then
    JOBID=`$SUBC $FSCRIPT.sh`
    # account for -terse changing the job number format
    if [[ $SUBC != *-terse* ]] ; then
        echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
        JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
    fi
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
    condor_submit $FSCRIPT.sh.condor
echo "RUN $RUN JOBID $JOBID"
    echo "RUN $RUN SCRIPT $FSCRIPT.sh"
    if [[ $SUBC != */dev/null* ]] ; then
        echo "RUN $RUN OLOG $FSCRIPT.sh.o$JOBID"
        echo "RUN $RUN ELOG $FSCRIPT.sh.e$JOBID"
    fi
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT.sh
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.$(date +"%s").dat"
elif [[ "$SUBC" == *simple* ]] ; then
    "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
fi

exit
