#!/bin/bash
# script to analyse VTS data files with lookup tables

# qsub parameters
h_cpu=00:29:00; h_vmem=2000M; tmpdir_size=4G

# EventDisplay version
EDVERSION=$($EVNDISPSYS/bin/mscw_energy --version | tr -d .)
IRFVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d . | sed -e 's/[a-zA-Z]*$//'`
# Directory with preprocessed data
DEFEVNDISPDIR="$VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/evndisp/"

if [ $# -lt 2 ]; then
# begin help message
echo "
MSCW_ENERGY data analysis: submit jobs from a simple run list

ANALYSIS.mscw_energy.sh <runlist> [output directory] [evndisp directory] [output directory] [Rec ID] [ATM] [evndisp log file directory]

required parameters:
			
    <runlist>               simple run list with one run number per line.    
    
optional parameters:

    [output directory]      directory where mscw.root files are written
                            default: <evndisp directory>

    [evndisp directory]     directory containing evndisp output ROOT files.
			    Default: $DEFEVNDISPDIR

    [Rec ID]                reconstruction ID. Default 0
                            (see EVNDISP.reconstruction.runparameter)
    
    [simulation type]       e.g. CARE_June2020 (this is the default)

    [ATM]                   set atmosphere ID (overwrite the value from the evndisp stage)

    [evndisp log file directory] directory with evndisplay log files (default: assume same 
                            as evndisp output ROOT files)

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
[[ "$2" ]] && ODIR=$2
[[ "$3" ]] && INPUTDIR=$3 || INPUTDIR="$DEFEVNDISPDIR"
[[ "$4" ]] && ID=$4 || ID=0
[[ "$5" ]] && FORCEDATMO=$5
[[ "$6" ]] && INPUTLOGDIR=$6 || INPUTLOGDIR=${INPUTDIR}
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

# run scripts are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/${DATE}-$(uuidgen)/MSCW.ANADATA"
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
    BFILE="${INPUTDIR%/}/$AFILE.root"

    # check if file exists
    TMPDIR="$VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/mscw/"
    if [[ -d "$TMPDIR" ]]; then
        TMPMDIR=$(getNumberedDirectory $AFILE "$TMPDIR")
        if [ -e "$TMPMDIR/$AFILE.mscw.root" ]; then
            echo "RUN $AFILE already processed; skipping"
            continue
        fi    
    fi
    # EVNDISP file
    if [ ! -e "$BFILE" ]; then
        TMPINDIR=$(getNumberedDirectory $AFILE ${INPUTDIR})
        if [ ! -e "$TMPINDIR/$AFILE.root" ]; then
            echo "ERR: File $BFILE does not exist !!!" >> mscw.errors.log
            continue
        fi
        BFILE="$TMPINDIR/$AFILE.root"
    fi
    echo "Now analysing $BFILE (ID=$ID)"

    TMPLOGDIR=${LOGDIR}
    # avoid reaching limits of number of files per
    # directory (e.g., on afs)
    if [[ ${NRUNS} -gt 5000 ]]; then
        TMPLOGDIR=${LOGDIR}-${AFILE:0:1}
        mkdir -p ${TMPLOGDIR}
    fi
    FSCRIPT="$TMPLOGDIR/MSCW.data-ID$ID-$AFILE"
    rm -f $FSCRIPT.sh

    sed -e "s|RECONSTRUCTIONID|$ID|" \
        -e "s|OUTPUTDIRECTORY|$ODIR|" \
        -e "s|INPUTLOGDIR|${INPUTLOGDIR}|" \
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
