#!/bin/bash
# XGBoost disp stereo and classification analysis on mscw data file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
RUN=RRUN
ODIR=OODIR
env_name="eventdisplay_ml"
XGB="XXGB"
XGB_TYPE=XGB_TTYPE
ANATYPE=ANALYSISTYPE

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$RUN
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

mkdir -p "${ODIR}"
echo -e "Output files will be written to:\n ${ODIR}"

check_conda_installation()
{
    if command -v conda &> /dev/null; then
        echo "Found conda installation."
    else
        echo "Error: found no conda installation."
        echo "exiting..."
        exit
    fi
    env_info=$(conda info --envs)
    if [[ "$env_info" == *"$env_name"* ]]; then
        echo "Found conda environment '$env_name'"
    else
        echo "Error: the conda environment '$env_name' does not exist."
        echo "exiting..."
        exit
    fi
}

check_conda_installation

eval "$(conda shell.bash hook)"
conda activate $env_name

# directory schema for preprocessed files
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

echo $RUN
MSCW_FILE="$(getNumberedDirectory $RUN ${VERITAS_PREPROCESSED_DATA_DIR}${VERITAS_ANALYSIS_TYPE:0:2}/mscw)/$RUN.mscw.root"
if [[ ! -e ${MSCW_FILE} ]]; then
    echo "File ${MSCW_FILE} not found. Exiting."
    exit
fi
RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${MSCW_FILE} -runinfo)
echo "RUNINFO $RUNINFO"
ZA=$(echo $RUNINFO | awk '{print $8}')
EPOCH=$(echo $RUNINFO | awk '{print $1}')
ATM=$(echo $RUNINFO | awk '{print $3}')
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg, epoch ${EPOCH}, ATM ${ATM}"
DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGB/${ANATYPE}/${EPOCH}_ATM${ATM}"
if [[ ! -d "${DISPDIR}" ]]; then
    echo "Error finding model directory $DISPDIR"
    exit
fi
OFIL=$(basename $MSCW_FILE .root)
if [[ "${XGB_TYPE}" == "stereo_analysis" ]]; then
    STEREO_PAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-stereo-parameter.json"
    BIN_ID=$(jq -r --arg za "$ZA" '
      .zenith[]
      | select(has("eval_min"))
      | select(($za|tonumber) >= (.eval_min|tonumber) and ($za|tonumber) < (.eval_max|tonumber))
      | .id' "$STEREO_PAR")
    if [[ -z "$BIN_ID" ]]; then
        echo "Error: No zenith bin found in $JSON_FILE for ZA=$ZA"
        exit 1
    fi
    DISPDIR="${DISPDIR}/${BIN_ID}/dispdir_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-stereo"
    OFIL="${ODIR}/${OFIL}.${XGB}_stereo"
elif [[ "${XGB_TYPE}" == "classification" ]]; then
    DISPDIR="${DISPDIR}/gammahadron_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-classify"
    OFIL="${ODIR}/${OFIL}.${XGB}_gh"
else
    echo "Invalid XGB type: ${XGB_TYPE}"
    exit
fi
echo "DispXGB directory $DISPDIR"
echo "DispXGB options $XGB"
echo "Output file $OFIL"
LOGFILE="$OFIL".log
rm -f "$LOGFILE"

$ML_EXEC --input_file "$MSCW_FILE" \
    --model_prefix "$DISPDIR" \
    --output_file "$OFIL.root" > "${LOGFILE}" 2>&1

python --version >> "${LOGFILE}"
conda list -n $env_name >> "${LOGFILE}"

conda deactivate
