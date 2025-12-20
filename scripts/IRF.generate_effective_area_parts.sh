#!/bin/bash
# calculate effective areas for a given point in the parameter space
# (output need to be combined afterwards)

# qsub parameters
h_cpu=13:29:00; h_vmem=8000M; tmpdir_size=20G

# EventDisplay version
IRFVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 8 ]; then
echo "
IRF generation: create partial effective area files from MC files
 (simulations that have been processed by both evndisp_MC and mscw_energy_MC)

IRF.generate_effective_area_parts.sh <cuts file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT] [uuid]

required parameters:

    <cuts file>             gamma/hadron cuts file (located in
                             \$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles)
                            (might be a list of cut files)

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

CUTSFILE="$1"
EPOCH="$2"
ATM="$3"
ZA="$4"
WOBBLE="$5"
NOISE="$6"
RECID="$7"
SIMTYPE="$8"
ANALYSIS_TYPE="${9:-}"
DISPBDT="${10:-0}"
UUID="${11:-$(date +"%y%m%d")-$(uuidgen)}"
# XGBVERSION="None" --> no XGB applied
XGBVERSION="xgb"

echo "IRF.generate_effective_area_parts for epoch $EPOCH, atmo $ATM, zenith $ZA, wobble $WOBBLE, noise $NOISE (DISP: $DISPBDT, XGB $XGBVERSION)"


if [[ -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    echo "Error: IRF production directory not found: $VERITAS_IRFPRODUCTION_DIR"
    exit 1
fi
# input directory containing mscw_energy products
INDIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/MSCW_RECID${RECID}"
if [[ ${DISPBDT} == "1" ]]; then
    INDIR=${INDIR}_DISP
fi
# output and log directories
ODIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma"
LOGDIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-EFFAREA-RECID${RECID}-${UUID}"
mkdir -p "$LOGDIR"
echo "Input: $INDIR"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"

# template string containing the name of processed simulation root file
MCFILE="${INDIR}/${ZA}deg_${WOBBLE}wob_NOISE${NOISE}.mscw.root"
# effective area output file
EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID${RECID}-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
# name of cut
CUTS_NAME=$(basename $CUTSFILE)
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
CUTS_NAME=${CUTS_NAME%%.dat}
echo "Cuts: $CUTSFILE $CUTS_NAME"
echo "MC file: $MCFILE"
echo "Eff area file: $EFFAREAFILE"
# run script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.effective_area_parallel_sub"
FSCRIPT="$LOGDIR/EA.ID${RECID}.${ZA}.${WOBBLE}.${NOISE}.${CUTS_NAME}.sh"
rm -f "$FSCRIPT"
sed -e "s|OUTPUTDIR|$ODIR|" \
    -e "s|EFFFILE|$EFFAREAFILE|" \
    -e "s|USEDISP|${DISPBDT}|" \
    -e "s|VERSIONIRF|$IRFVERSION|" \
    -e "s|VERSIONXGB|$XGBVERSION|" \
    -e "s|DATAFILE|$MCFILE|" \
    -e "s|GAMMACUTS|${CUTSFILE}|" $SUBSCRIPT.sh > $FSCRIPT

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
    JOBID=`$SUBC $FSCRIPT`
    echo "JOBID: $JOBID"
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT $h_vmem $tmpdir_size
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT &> $(basename $FSCRIPT .sh).log" >> "$LOGDIR/runscripts.dat"
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT" | tee "$(basename $FSCRIPT .sh).log"
fi
