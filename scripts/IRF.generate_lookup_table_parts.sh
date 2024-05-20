#!/bin/bash
# fill lookup tables for a given point in the parameter space
# (output need to be combined afterwards)

# qsub parameters
h_cpu=03:29:00; h_vmem=16000M; tmpdir_size=20G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 7 ]; then
echo "
IRF generation: create partial (for one point in the parameter space) lookup
                tables from MC evndisp ROOT files

IRF.generate_lookup_table_parts.sh <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type]

required parameters:

    <epoch>                 array epoch (e.g., V4, V5, V6)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]

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
EPOCH=$1
ATM=$2
ZA=$3
WOBBLE=$4
NOISE=$5
RECID=$6
SIMTYPE=$7
[[ "$8" ]] && ANALYSIS_TYPE=$8  || ANALYSIS_TYPE=""
[[ "${9}" ]] && UUID=${9} || UUID=${DATE}-$(uuidgen)
EVNIRFVERSION="v4N"

_sizecallineraw=$(grep "* s " ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/ThroughputCorrection.runparameter | grep " ${EPOCH} ")
EPOCH_LABEL=$(echo "$_sizecallineraw" | awk '{print $3}')

# input directory containing evndisp products
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
fi
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched:"
    echo "$INDIR"
    exit 1
fi
echo "Input file directory: $INDIR"

# Output file directory
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH_LABEL}_ATM${ATM}_gamma/Tables"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

LOGDIR="${VERITAS_IRFPRODUCTION_DIR}/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-MAKETABLES-${UUID}/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.lookup_table_parallel_sub"

echo "Processing Zenith = $ZA, Wobble = $WOBBLE, Noise = $NOISE"


# make run script
FSCRIPT="$LOGDIR/TABLE-$EPOCH-MK-TBL.$DATE.MC-$SIMTYPE-$ZA-$WOBBLE-$NOISE-$EPOCH-$ATM-$RECID"
rm -f "$FSCRIPT.sh"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|ATMOSPHERE|$ATM|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|SIMULATIONTYPE|$SIMTYPE|" \
    -e "s|INPUTDIR|$INDIR|" \
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
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT.sh
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi
echo "LOG/SUBMIT DIR: ${LOGDIR}"
