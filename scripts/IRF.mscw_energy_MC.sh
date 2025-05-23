#!/bin/bash
# submit mscw_energy to analyse MC files with lookup tables

# qsub parameters
h_cpu=10:29:00; h_vmem=8000M; tmpdir_size=100G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)
EVNIRFVERSION="v4N"

if [ $# -lt 8 ]; then
echo "
IRF generation: analyze simulation evndisp files using mscw_energy

IRF.mscw_energy_MC.sh <table file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT] [cut list] [uuid]

required parameters:

    <table file>            mscw_energy lookup table file (expected to be in \$VERITAS_EVNDISP_AUX/Tables)

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

    [dispBDT]               use dispDBDT angular reconstruction
                            (default: 0; use: 1)

    [cut list]              cut list file (full path)
                            This triggers the effective area generation. No data files
                            from the mscw_energy stage are written to disk.

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

TABFILE=${1%.root}.root
EPOCH="$2"
ATM="$3"
ZA="$4"
WOBBLE="$5"
NOISE="$6"
RECID="$7"
SIMTYPE="$8"
ANALYSIS_TYPE="${9:-}"
DISPBDT="${10:-0}"
EFFAREACUTLIST="${11:-NOEFFAREA}"
UUID="${12:-$(date +"%y%m%d")-$(uuidgen)}"

echo "IRF.mscw_energy_MC for epoch $EPOCH, atmo $ATM, zenith $ZA, wobble $WOBBLE, noise $NOISE (DISP: $DISPBDT)"

TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$(basename $TABFILE)"
if [[ ! -f "$TABFILE" ]]; then
    echo "Error: table file not found: $TABFILE"
    exit 1
fi

if [[ -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    echo "Error: IRF production directory not found: $VERITAS_IRFPRODUCTION_DIR"
    exit 1
fi
# input directory containing evndisp products
INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
# output and log directories
ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma"
LOGDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-MSCW-RECID${RECID}-${UUID}"
mkdir -p "$LOGDIR"
echo "Input: $INDIR"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"

# run script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.mscw_energy_MC_sub"
FSCRIPT="$LOGDIR/MSCW-$EPOCH-$ATM-$ZA-$WOBBLE-$NOISE-ID${RECID}-$DISPBDT.sh"
rm -f "$FSCRIPT"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|ATMOSPHERE|$ATM|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|ANALYSISTYPE|$ANALYSIS_TYPE|" \
    -e "s|USEDISP|$DISPBDT|" \
    -e "s|VERSIONIRF|$EDVERSION|" \
    -e "s|SIMULATIONTYPE|$SIMTYPE|" \
    -e "s|TABLEFILE|$TABFILE|" \
    -e "s|INPUTDIR|$INDIR|" \
    -e "s|EEFFAREACUTLIST|$EFFAREACUTLIST|" \
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
