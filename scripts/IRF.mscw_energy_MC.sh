#!/bin/bash
# script to analyse MC files with lookup tables

# qsub parameters
h_cpu=10:29:00; h_vmem=8000M; tmpdir_size=100G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)
EVNIRFVERSION="v4N"

if [ $# -lt 8 ]; then
echo "
IRF generation: analyze simulation evndisp ROOT files using mscw_energy

IRF.mscw_energy_MC.sh <table file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT] [uuid]

required parameters:

    <table file>            mscw_energy lookup table file (expected to be in \$VERITAS_EVNDISP_AUX/Tables)

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

    [dispBDT]               use dispDBDT angular reconstruction
                            (default: 0; use: 1)

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

# Parse command line arguments
TABFILE=$1
TABFILE=${TABFILE%%.root}.root
EPOCH=$2
ATM=$3
ZA=$4
WOBBLE=$5
NOISE=$6
RECID=$7
SIMTYPE=$8
[[ "$9" ]] && ANALYSIS_TYPE=$9 || ANALYSIS_TYPE=""
[[ "${10}" ]] && DISPBDT=${10} || DISPBDT=0
[[ "${11}" ]] && UUID=${11} || UUID=$(date +"%y%m%d")-$(uuidgen)

# Check that table file exists
if [[ "$TABFILE" == `basename "$TABFILE"` ]]; then
    TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
fi
if [[ ! -f "$TABFILE" ]]; then
    echo "Error, table file not found, exiting..."
    echo "$TABFILE"
    exit 1
fi

# input directory containing evndisp products
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
fi
echo "Input file directory: $INDIR"

# Output file directory
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma"
fi
echo -e "Output files will be written to:\n $ODIR"
[[ ! -d "$ODIR" ]] && mkdir -p "$ODIR" && chmod g+w "$ODIR"

LOGDIR="${VERITAS_IRFPRODUCTION_DIR}/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-MSCW-RECID${RECID}-${UUID}"
echo -e "Log files will be written to:\n $LOGDIR"
[[ ! -d "$LOGDIR" ]] && mkdir -p "$LOGDIR"

SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.mscw_energy_MC_sub"

echo "Processing Zenith = $ZA, Wobble = $WOBBLE, Noise = $NOISE (DISP: $DISPBDT)"

# make run script
FSCRIPT="$LOGDIR/MSCW-$EPOCH-$ATM-$ZA-$WOBBLE-$NOISE-ID${RECID}-$DISPBDT"
rm -f "$FSCRIPT.sh"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|ATMOSPHERE|$ATM|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|ANALYSISTYPE|${ANALYSIS_TYPE}|" \
    -e "s|USEDISP|${DISPBDT}|" \
    -e "s|VERSIONIRF|${IRFVERSION}|" \
    -e "s|SIMULATIONTYPE|$SIMTYPE|" \
    -e "s|TABLEFILE|$TABFILE|" \
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
