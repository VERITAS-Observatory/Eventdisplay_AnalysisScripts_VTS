#!/bin/bash
# shellcheck disable=SC2086
# EVNDISPSYS may include an apptainer exec prefix and must split into command words.
# XGBoost disp stereo and classification analysis on mscw data file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
RUN=RRUN
ODIR=OODIR
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
ENV_PREFIX="CCONDA_ENV_PREFIX"
HELPER_SCRIPTS_DIR="HHELPER_SCRIPTS_DIR"
ENV_SNAPSHOT_DIR="EENV_SNAPSHOT_DIR"
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

# shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
evndisp_ml_setup_python_cache "$TEMPDIR" "$RUN"
evndisp_ml_use_env_prefix "$ENV_PREFIX" "$env_name"

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
    echo "${ODIR}"
}

echo $RUN
MSCW_FILE="$(getNumberedDirectory $RUN "${VERITAS_PREPROCESSED_DATA_DIR}""${VERITAS_ANALYSIS_TYPE:0:2}"/mscw)/$RUN.mscw.root"
if [[ ! -e ${MSCW_FILE} ]]; then
    echo "File ${MSCW_FILE} not found. Exiting."
    exit
fi
RUNINFO=$($EVNDISPSYS/bin/printRunParameter "${MSCW_FILE}" -runinfo)
echo "RUNINFO $RUNINFO"
ZA=$(echo "$RUNINFO" | awk '{print $8}')
EPOCH=$(echo "$RUNINFO" | awk '{print $1}')
ATM=$(echo "$RUNINFO" | awk '{print $3}')
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg, epoch ${EPOCH}, ATM ${ATM}"
DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGBs/${ANATYPE}/${EPOCH}_ATM${ATM}"
if [[ ! -d "${DISPDIR}" ]]; then
    echo "Error finding model directory $DISPDIR"
    exit
fi
OFIL=$(basename "$MSCW_FILE" .root)
if [[ "${XGB_TYPE}" == "stereo_analysis" ]]; then
    STEREO_PAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-stereo-parameter.json"
    BIN_ID=$(jq -r --arg za "$ZA" '
      .zenith[]
      | select(has("eval_min"))
      | select(($za|tonumber) >= (.eval_min|tonumber) and ($za|tonumber) < (.eval_max|tonumber))
      | .id' "$STEREO_PAR")
    if [[ -z "$BIN_ID" ]]; then
        echo "Error: No zenith bin found in $STEREO_PAR for ZA=$ZA"
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

evndisp_ml_log_environment "${LOGFILE}" "$env_name" "$ENV_SNAPSHOT_DIR" "$ENV_PREFIX"
