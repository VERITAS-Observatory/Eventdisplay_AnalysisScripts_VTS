#!/bin/bash
# script to analyse data files with anasum (parallel analysis)

# qsub parameters
h_cpu=0:59:00; h_vmem=4000M; tmpdir_size=1G

if [[ "$#" -lt 4 ]]; then
# begin help message
echo "
ANASUM parallel data analysis: submit jobs from an anasum run list

ANALYSIS.anasum_parallel.sh <anasum run list> <mscw directory> <output directory> <run parameter file> [radial acceptances]

required parameters:

    <anasum run list>       full anasum run list

    <mscw directory>        directory containing the mscw.root files

    <output directory>      anasum output files are written to this directory

    <run parameter file>    anasum run parameter file
                            (in \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/;
                             see ANASUM.runparameter for an example)

Run ANALYSIS.anasum_combine.sh once all parallel jobs have finished!

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RUNLIST=$1
INDIR=$2
ODIR=$3
RUNP=$4

# Check that run list exists
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, anasum runlist $RUNLIST not found, exiting..."
    exit 1
fi

# create extra stdout for duplication of command output
# look for ">&5" below
exec 5>&1

# Check that run parameter file exists
if [[ "$RUNP" == `basename $RUNP` ]]; then
    RUNP="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNP"
fi
if [[ ! -f "$RUNP" ]]; then
    echo "Error, anasum run parameter file not found, exiting..."
    echo "(searched for $RUNP)"
    exit 1
fi

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/submit.ANASUM.ANADATA-${DATE}-$(uuidgen)"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# temporary run list
DATECODE=`date +%Y%m%d`
TEMPLIST=`basename "$RUNLIST"`
TEMPLIST="$LOGDIR/$DATECODE.PID$$.$TEMPLIST-$(uuidgen).tmp"
rm -f "$TEMPLIST"
cat "$RUNLIST" | grep "*" >> "$TEMPLIST"

# output directory for anasum products
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
ODIRBASE=`basename "$ODIR"`
echo "Output directory base name: $ODIRBASE"

# get list of runs
NLINES=`cat "$TEMPLIST" | wc -l`
NRUNS=`cat "$TEMPLIST" | grep -v "VERSION" | wc -l`
echo "Total number of runs to analyse: $NRUNS"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.anasum_sub"
TIMETAG=`date +"%s"`

# loop over all runs
for ((i=1; i <= $NLINES; i++)); do
    echo
    VERSION=`cat "$TEMPLIST" | grep VERSION`
    LINE=`head -n $i "$TEMPLIST" | tail -n 1`
    RUN=`head -n $i "$TEMPLIST" | tail -n 1 | awk '{print $2}'`

    if [[ $RUN != "VERSION" ]]; then
        # output file name
        ONAME="$RUN.anasum"

        # temporary per-run file list
        RUNTEMPLIST="$LOGDIR/qsub_analyse_fileList_${ODIRBASE}_${RUN}_${DATECODE}_PID$$"
        rm -f $RUNTEMPLIST
        echo "$VERSION" > "$RUNTEMPLIST"
        echo "$LINE" >> $RUNTEMPLIST

        # prepare run scripts
        FSCRIPT="$LOGDIR/qsub_analyse-$DATE-RUN$RUN-$(date +%s)"
        echo "Run script written to $FSCRIPT"
        echo "Temporary run list written to $RUNTEMPLIST"

        sed -e "s|FILELIST|$RUNTEMPLIST|" \
            -e "s|DATADIR|$INDIR|"        \
            -e "s|OUTDIR|$ODIR|"          \
            -e "s|OUTNAME|$ONAME|"        \
            -e "s|RUNNNNN|$RUN|"          \
            -e "s|RUNPARAM|$RUNP|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"

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
            # condor_submit $FSCRIPT.sh.condor
	    echo "RUN $RUN JOBID $JOBID"
            echo "RUN $RUN SCRIPT $FSCRIPT.sh"
            if [[ $SUBC != */dev/null* ]] ; then
                echo "RUN $RUN OLOG $FSCRIPT.sh.o$JOBID"
                echo "RUN $RUN ELOG $FSCRIPT.sh.e$JOBID"
            fi
	elif [[ $SUBC == *sbatch* ]]; then
            $SUBC $FSCRIPT.sh
        elif [[ $SUBC == *parallel* ]]; then
            echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.$TIMETAG.dat"
        elif [[ "$SUBC" == *simple* ]] ; then
	    "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
	fi
    fi
done
# submit all condor jobs at once
if [[ $SUBC == *condor* ]]; then
    $EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit
fi

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    cat "$LOGDIR/runscripts.$TIMETAG.dat" | $SUBC
fi

rm -f "$TEMPLIST"

echo ""
echo "============================================================================================"

echo "After all runs have been analysed, combine the results by calling"
echo $( dirname "$0" )"/ANALYSIS.anasum_combine.sh \\"
echo "	$RUNLIST \\"
echo "	$ODIR \\"
echo "	anasumCombined.root \\"
echo "	$RUNP"
echo "============================================================================================"
echo ""

exit
