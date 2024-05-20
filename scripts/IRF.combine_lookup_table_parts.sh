#!/bin/bash
# script to combine several table file into one

# qsub parameters
h_cpu=20:29:00; h_vmem=64000M; tmpdir_size=10G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 4 ]; then
echo "
IRF generation: create a lookup table from a set of partial table files

IRF.combine_lookup_table_parts.sh <table file name> <epoch> <atmosphere> <Rec ID> <sim type> <analysis type>

required parameters:

    <table file name>       file name of combined lookup table

    <epoch>                 array epoch (e.g., V4, V5, V6)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <sim type>              simulation type (e.g. GRISU-SW6, CARE_June1425)

optional parameters:

    [analysis type]         type of analysis (default="")

    [uuid]                  UUID used for submit directory

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# date used in run scripts / log file directories
DATE=`date +"%y%m%d"`

# Parse command line arguments
OFILE=$1
EPOCH=$2
ATM=$3
RECID=$4
SIMTYPE=$5
[[ "$6" ]] && ANALYSIS_TYPE=$6  || ANALYSIS_TYPE=""
[[ "${7}" ]] && UUID=${7} || UUID=${DATE}-$(uuidgen)

# input directory containing table files
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/Tables/"
fi
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched:"
    echo "$INDIR"
    exit 1
fi
echo "Input file directory: $INDIR"

# Output file directory
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/Tables/"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

if [[ -f $OFILE ]]; then
    echo "ERROR: table file $ODIR/$OFILE exists; move it or delete it"
    exit 1
fi

# run scripts and output are written into this directory
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/MSCW.MAKETABLES/${ANALYSIS_TYPE}/submit-COMBINETABLES-${UUID}/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# Create list of partial table files
FLIST=$OFILE.list
rm -f "$ODIR/$FLIST"
ls -1 $INDIR/*ID${RECID}.root > "$ODIR/$FLIST"
NFIL=`cat "$ODIR/$FLIST" | wc -l`
if [[ $NFIL = "0" ]]; then
   echo "No lookup table root files found"
   exit
fi
echo "$FLIST"
echo "LOOKUPTABLE $OFILE"

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.lookup_table_combine_sub"

# make run script
FSCRIPT="$LOGDIR/TABLES-COMBINE.$OFILE.$DATE.MC"

sed -e "s|TABLELIST|$FLIST|" \
    -e "s|OUTPUTFILE|$OFILE|" \
    -e "s|OUTPUTDIR|$ODIR|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x "$FSCRIPT.sh"
echo "Run script written to: $FSCRIPT"

# run locally or on cluster
SUBC=`$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
if [[ $SUBC == *qsub* ]]; then
    JOBID=`$SUBC $FSCRIPT.sh`
    echo "JOBID: $JOBID"
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs at once:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
    echo
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
fi
echo "LOG/SUBMIT DIR: ${LOGDIR}"
