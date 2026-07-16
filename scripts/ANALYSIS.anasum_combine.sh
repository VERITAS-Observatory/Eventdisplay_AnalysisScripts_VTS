#!/bin/bash
# script to combine anasum files processed in parallel mode

# qsub parameters
# shellcheck disable=SC2034  # SGE resource directives, read by job scheduler
h_cpu=0:59:00; h_vmem=12000M; tmpdir_size=150G
# shellcheck source=scripts/helper_scripts/UTILITY.submitJob.sh
source "$(dirname "$0")/helper_scripts/UTILITY.submitJob.sh"

if [[ $# -lt 3 ]]; then
# begin help message
echo "
ANASUM parallel data analysis: combine parallel-processed anasum runs

ANALYSIS.anasum_combine.sh <anasum run list> <anasum directory> <output file name> [run parameter file]

required parameters:

    <anasum run list>       full anasum run list
                            (with effective areas, file names, etc.)
                            or short run list
                            (run numbers only)

    <anasum directory>      input directory containing anasum root files

    <output file name>      name of combined anasum file (full path)

optional parameters:

    [run parameter file]    anasum run parameter file (located in
                            \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/;
                            default is ANASUM.runparameter)

IMPORTANT! Run only after all ANALYSIS.anasum_parallel_from_runlist.sh jobs have finished!

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh" || exit 1
fi

# Parse command line arguments
RUNLIST=$1
DDIR=$2
OUTFILE=$3
OUTFILE=${OUTFILE%%.root}
[[ "$4" ]] && RUNP=$4 || RUNP="ANASUM.runparameter"

# Check that run list exists
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, anasum runlist $RUNLIST not found, exiting..."
    exit 1
fi
NRUNLIST_LINES=$(wc -l < "$RUNLIST")

# Check that run parameter file exists
if [[ "$RUNP" == $(basename "$RUNP") ]]; then
    RUNP="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNP"
fi
if [[ ! -f "$RUNP" ]]; then
    echo "Error, anasum run parameter file '$RUNP' not found, exiting..."
    exit 1
fi

# directory for run scripts
DATE=$(date +"%y%m%d")
LOGDIR="$VERITAS_USER_LOG_DIR/ANASUM.COMBINE-${DATE}-$(uuidgen)"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
cp -f "$RUNLIST" "$LOGDIR/" || { echo "Error: failed to copy runlist '$RUNLIST' to '$LOGDIR'"; exit 1; }

# Job submission script
SUBSCRIPT="$(dirname "$0")/helper_scripts/ANALYSIS.anasum_combine_sub"

FSCRIPT="$LOGDIR/anasum_combine-$DATE-$(basename "$OUTFILE")-$(date +%s)"
echo "Run script written to $FSCRIPT"

# Check that anasum output files exist before combining
NANASUMFILES=$(find "$DDIR" -maxdepth 1 -name "*.anasum.root" | wc -l)
if [[ $NANASUMFILES -eq 0 ]]; then
    echo "Error: no .anasum.root files found in $DDIR"
    echo "Run ANALYSIS.anasum_parallel_from_runlist.sh and wait for completion before combining."
    exit 1
fi
echo "Found $NANASUMFILES anasum output files in $DDIR"

sed -e "s|RRUNLIST|$LOGDIR/$(basename "$RUNLIST")|" \
    -e "s|DDDIR|$DDIR|" \
    -e "s|RRUNP|$RUNP|" \
    -e "s|OOUTFILE|$OUTFILE|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"
chmod u+x "$FSCRIPT.sh"

# run locally or on cluster
SUBC=$("$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh")
SUBC=$(eval "echo \"$SUBC\"")
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
if [[ $SUBC == *condor* && $NRUNLIST_LINES -gt 500 ]]; then
    h_vmem=32000M
    echo "Run list has $NRUNLIST_LINES lines; requesting $h_vmem memory for HTCondor"
fi
RUNSCRIPT_LIST="$LOGDIR/runscripts.$(date +"%s").dat"
submit_job "$FSCRIPT.sh" "$FSCRIPT.sh &> $FSCRIPT.log" "$RUNSCRIPT_LIST"
if [[ $SUBC == *qsub* ]]; then
    echo "OUTFILE $OUTFILE JOBID $JOBID"
    echo "OUTFILE $OUTFILE SCRIPT $FSCRIPT.sh"
    if [[ $SUBC != */dev/null* ]] ; then
        echo "OUTFILE $OUTFILE OLOG $FSCRIPT.sh.o$JOBID"
        echo "OUTFILE $OUTFILE ELOG $FSCRIPT.sh.e$JOBID"
    fi
fi
