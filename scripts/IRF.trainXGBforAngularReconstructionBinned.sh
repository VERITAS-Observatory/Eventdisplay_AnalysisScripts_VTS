#!/bin/bash
# train XGB for angular reconstruction

h_cpu=47:29:00; h_vmem=16000M; tmpdir_size=100G

EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 7 ]; then
echo "
XGB (BDT) training for stereo reconstruction from MC mscw files for different zenith angle bins

IRF.trainXGBforAngularReconstructionBinned.sh <epoch> <atmosphere> <zenith range> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type]

required parameters:

    <epoch>                 array epoch (e.g., V4, V5, V6)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith range>          zenith angle range (SZE, MZE, LZE, XZE)

    <offset angle>          list of offset angle of simulations [deg]

    <NSB level>             list of NSB level of simulations [MHz]

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
# output and log directories
ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/TrainXGBStereoAnalysisBinned_v0.5.0/${ZA}/"
LOGDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-trainXGBStereoAnalysis-RECID${RECID}-${UUID}"
mkdir -p "$ODIR"
chmod g+w "$ODIR"
mkdir -p "$LOGDIR"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"

# prepare list of input files
MSCWLIST="$ODIR/xgbFiles.list"
rm -f ${MSCWLIST}
touch ${MSCWLIST}

INDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/MSCW_RECID0_DISP"

STEREO_PAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-stereo-parameter.json"
TRAIN_ANGLES=$(jq -r ".zenith[] | select(.id==\"$ZA\") | .train | join(\" \")" $STEREO_PAR)
if [[ -z "$TRAIN_ANGLES" ]]; then
    echo "Error: Bin ID $ZA_BIN not found in $JSON_FILE"
    exit 1
fi

for W in ${WOBBLE}
do
    for N in ${NOISE}
    do
        for DEG in ${TRAIN_ANGLES}
        do
            FILE_PATH="${INDIR}/${DEG}deg_${W}wob_NOISE${N}.mscw.root"
            if [[ -f "$FILE_PATH" ]]; then
                echo "$FILE_PATH" >> "${MSCWLIST}"
            else
                echo "Warning: File not found: $FILE_PATH"
            fi
        done
    done
done
echo "FILE LIST: ${MSCWLIST}"

SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.trainXGBforAngularReconstruction_sub.sh"

echo "Processing Zenith = $ZA, Noise = $NOISE, Wobble = $WOBBLE"

FSCRIPT="$LOGDIR/trainXGBStereoAnalysis.ID${RECID}.${EPOCH}.ATM${ATM}.${ZA}.sh"
sed -e "s|OUTPUTDIR|$ODIR|" \
    -e "s|MSCWLIST|$MSCWLIST|" "$SUBSCRIPT" > "$FSCRIPT"

chmod u+x "$FSCRIPT"
echo "$FSCRIPT"

# run locally or on cluster
SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo $SUBC
    exit
fi
if [[ $SUBC == *qsub* ]]; then
    JOBID=`$SUBC $FSCRIPT`
    echo "RUN $RUNNUM: JOBID $JOBID"
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT $h_vmem $tmpdir_size
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs at once:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
    echo
elif [[ $SUBC == *sbatch* ]]; then
        $SUBC $FSCRIPT
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
fi
