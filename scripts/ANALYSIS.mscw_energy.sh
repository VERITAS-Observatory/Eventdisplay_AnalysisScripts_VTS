#!/bin/bash
# script to analyse data files with lookup tables

# qsub parameters
h_cpu=00:29:00; h_vmem=4000M; tmpdir_size=4G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)
IRFVERSION="$EDVERSION"

if [ $# -lt 2 ]; then
echo "
MSCW_ENERGY data analysis: submit jobs from a simple run list

ANALYSIS.mscw_energy.sh <runlist> [output directory] [evndisp directory] [preprocessing skip] [Rec ID] [ATM]

required parameters:

    <runlist>               simple run list with one run number per line.

optional parameters:

    [output directory]      directory where mscw.root files are written
                            default: <evndisp directory>

    [evndisp directory]     directory containing evndisp output ROOT files.
			    Default: $DEFEVNDISPDIR

   [preprocessing skip]    Skip if run is already processed and found in the preprocessing
                           directory (1=skip, 0=run the analysis; default 1)

    [Rec ID]                reconstruction ID. Default 0
                            (see EVNDISP.reconstruction.runparameter)

    [simulation type]       e.g. CARE_June2020 (this is the default)

    [ATM]                   set atmosphere ID (overwrite the value from the evndisp stage)


The analysis type (cleaning method; direction reconstruction) is read from the \$VERITAS_ANALYSIS_TYPE environmental
variable (e.g., AP_DISP, NN_DISP; here set to: \"$VERITAS_ANALYSIS_TYPE\").

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# create extra stdout for duplication of command output
# look for ">&5" below
exec 5>&1

# Parse command line arguments
RLIST=$1
[[ "$2" ]] && ODIR=$2
[[ "$3" ]] && INPUTDIR=$3 || INPUTDIR="$VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/evndisp"
[[ "$4" ]] && SKIP=$4 || SKIP=1
[[ "$5" ]] && ID=$5 || ID=0
[[ "$6" ]] && FORCEDATMO=$6
DISPBDT="1"

# Read runlist
if [ ! -f "$RLIST" ] ; then
    echo "Error, runlist $RLIST not found, exiting..."
    exit 1
fi
FILES=`cat "$RLIST"`

NRUNS=`cat "$RLIST" | wc -l `
echo "total number of runs to analyze: $NRUNS"
echo

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/MSCW.${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.mscw_energy_sub"
TIMETAG=`date +"%s"`

# directory schema
getNumberedDirectory()
{
    TRUN="$1"
    IDIR="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${IDIR}/${TRUN:0:1}/"
    else
        ODIR="${IDIR}/${TRUN:0:2}/"
    fi
    echo ${ODIR}
}


#########################################
# loop over all files in files loop
for AFILE in $FILES
do
    echo "Now analysing run $AFILE"
    BFILE="${INPUTDIR%/}/$AFILE.root"

    # check if file is on disk
    if [[ $SKIP == "1" ]]; then
        TMPDIR="$VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/mscw/"
        if [[ -d "$TMPDIR" ]]; then
            TMPMDIR=$(getNumberedDirectory $AFILE "$TMPDIR")
            if [ -e "$TMPMDIR/$AFILE.mscw.root" ]; then
                echo "RUN $AFILE already processed; skipping"
                continue
            fi
        fi
    fi
    # EVNDISP file
    if [ ! -e "$BFILE" ]; then
        TMPINDIR=$(getNumberedDirectory $AFILE ${INPUTDIR})
        if [ ! -e "$TMPINDIR/$AFILE.root" ]; then
            echo "ERR: File $BFILE does not exist" >> mscw.errors.log
            continue
        fi
        BFILE="$TMPINDIR/$AFILE.root"
    fi
    echo "Processing $BFILE (ID=$ID)"

    TMPLOGDIR=${LOGDIR}
    # avoid reaching limits of number of files per
    # directory (e.g., on afs)
    if [[ ${NRUNS} -gt 1000 ]]; then
        TMPLOGDIR=${LOGDIR}/MSCW_${AFILE:0:1}
        mkdir -p ${TMPLOGDIR}
    fi
    FSCRIPT="$TMPLOGDIR/MSCW.data-ID$ID-$AFILE"
    rm -f $FSCRIPT.sh

    sed -e "s|RECONSTRUCTIONID|$ID|" \
        -e "s|OUTPUTDIRECTORY|$ODIR|" \
        -e "s|BDTDISP|${DISPBDT}|" \
        -e "s|VERSIONIRF|${IRFVERSION}|" \
        -e "s|EVNDISPFILE|$BFILE|" $SUBSCRIPT.sh > $FSCRIPT.sh

    chmod u+x $FSCRIPT.sh
    echo $FSCRIPT.sh

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
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${TMPLOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
    elif [[ $SUBC == *sbatch* ]]; then
        $SUBC $FSCRIPT.sh
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> ${TMPLOGDIR}/runscripts.$TIMETAG.dat
        echo "RUN $AFILE OLOG $FSCRIPT.log"
    elif [[ "$SUBC" == *simple* ]] ; then
        "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
    fi
done

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    cat $TMPLOGDIR/runscripts.$TIMETAG.dat | $SUBC
fi
