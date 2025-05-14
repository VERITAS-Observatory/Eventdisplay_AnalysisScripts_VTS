#!/bin/bash
# fill lookup tables for a given point in the parameter space
# (generated tables need to be combined afterwards)

# qsub parameters
h_cpu=03:29:00; h_vmem=12000M; tmpdir_size=20G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)
EVNIRFVERSION="v4N"

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

    <sim type>              simulation type (e.g. GRISU, CARE_June1425)

optional parameters:

    [analysis type]         type of analysis (default="")

    [uuid]                  UUID used for submit directory

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ -z "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

EPOCH="$1"
ATM="$2"
ZA="$3"
WOBBLE="$4"
NOISE="$5"
RECID="$6"
SIMTYPE="$7"
ANALYSIS_TYPE="${8:-}"
UUID="${9:-$(date +"%y%m%d")-$(uuidgen)}"

if [[ -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    echo "Error: IRF production directory not found: $VERITAS_IRFPRODUCTION_DIR"
    exit 1
fi
# input directory containing evndisp products
INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched:"
    echo "$INDIR"
    exit 1
fi
# output and log directories
ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/Tables"
LOGDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-MAKETABLES-${UUID}/"
mkdir -p "$ODIR"
chmod g+w "$ODIR"
mkdir -p "$LOGDIR"
echo "Input: $INDIR"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"

# run script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.lookup_table_parallel_sub"
FSCRIPT="$LOGDIR/TABLE-$EPOCH-MK-TBL.MC-$SIMTYPE-$ZA-$WOBBLE-$NOISE-$EPOCH-$ATM-$RECID.sh"
rm -f "$FSCRIPT"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|ATMOSPHERE|$ATM|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|VERSIONIRF|$EDVERSION|" \
    -e "s|SIMULATIONTYPE|$SIMTYPE|" \
    -e "s|INPUTDIR|$INDIR|" \
    -e "s|OUTPUTDIR|$ODIR|" \
    "$SUBSCRIPT.sh" > "$FSCRIPT"

chmod u+x "$FSCRIPT"
echo "Run script: $FSCRIPT"

# Job submission
SUBMISSION_SCRIPT="$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh"
SUBC=$("$SUBMISSION_SCRIPT")
if [[ $SUBC == *"ERROR"* ]]; then
    echo "Error: reading submission type from $SUBMISSION_SCRIPT"
    exit 1
fi
if [[ $SUBC == *qsub* ]]; then
    JOBID=`$SUBC $FSCRIPT.sh`
    echo "JOBID: $JOBID"
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT.sh
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi
