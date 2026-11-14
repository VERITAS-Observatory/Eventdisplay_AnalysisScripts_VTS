#!/bin/bash
# shellcheck disable=SC2086
# XGBoost disp stereo and classification analysis on mscw MC file

# Don't do set -e: the environment is logged after the ML step.
# The ML exit status is checked explicitly (evndisp_ml_check_apply).

MSCW_FILE=FFILE
ODIR=OODIR
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
ENV_PREFIX="CCONDA_ENV_PREFIX"
HELPER_SCRIPTS_DIR="HHELPER_SCRIPTS_DIR"
ENV_SNAPSHOT_DIR="EENV_SNAPSHOT_DIR"
XGB="XXGB"
XGB_TYPE=XGB_TTYPE
ANATYPE=ANALYSISTYPE
MAXCORES=1
VARIANT="VVARIANT"
SMEAR_CONFIG="SSMEAR_CONFIG"
MODEL_ROOT="MMODEL_ROOT"

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$(basename $MSCW_FILE .root)
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

mkdir -p "${ODIR}"
echo -e "Output files will be written to:\n ${ODIR}"

# shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
# shellcheck source=scripts/helper_scripts/UTILITY.xgb_checks.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.xgb_checks.sh"
evndisp_ml_setup_python_cache "$TEMPDIR" "$(basename "$MSCW_FILE" .root)"
if [[ -z "${EVNDISP_APPTAINER:-}" ]]; then
    evndisp_ml_use_env_prefix "$ENV_PREFIX" "$env_name"
fi

if [[ ! -e ${MSCW_FILE} ]]; then
    echo "File ${MSCW_FILE} not found. Exiting."
    exit 1
fi
if [[ -n "${EVNDISP_APPTAINER:-}" ]]; then
    APPTAINER_MOUNT=(
        --bind "${VERITAS_EVNDISP_AUX_DIR}:${VERITAS_EVNDISP_AUX_DIR}"
        --bind "${VERITAS_USER_DATA_DIR}:${VERITAS_USER_DATA_DIR}"
        --bind "$(dirname "${MSCW_FILE}")":"$(dirname "${MSCW_FILE}")"
        --bind "${ODIR}:${ODIR}"
        --bind "${TEMPDIR}:${TEMPDIR}"
    )
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT[*]}"
    APPTAINER_ENV_VALUE="VERITAS_EVNDISP_AUX_DIR=${VERITAS_EVNDISP_AUX_DIR},VERITAS_USER_DATA_DIR=${VERITAS_USER_DATA_DIR},ODIR=${ODIR},TMPDIR=${TEMPDIR},PYTHONPYCACHEPREFIX=${PYTHONPYCACHEPREFIX}"
    APPTAINER_EXEC=(apptainer exec --no-mount bind-paths --cleanenv)
    APPTAINER_EXEC+=(--env "${APPTAINER_ENV_VALUE}")
    APPTAINER_EXEC+=("${APPTAINER_MOUNT[@]}")
    APPTAINER_EXEC+=("${EVNDISP_APPTAINER}")
fi
# run info (epoch, atmosphere, zenith angle) from Eventdisplay-ML; no compiled Eventdisplay required
RUN_INFO_EXEC=(eventdisplay-ml-print-run-info)
if [[ -n "${EVNDISP_APPTAINER:-}" ]]; then
    RUN_INFO_EXEC=("${APPTAINER_EXEC[@]}" eventdisplay-ml-print-run-info)
fi
RUNINFO=$("${RUN_INFO_EXEC[@]}" "${MSCW_FILE}")
if [[ -z "$RUNINFO" ]]; then
    echo "Error: failed to read run information from ${MSCW_FILE}"
    exit 1
fi
echo "RUNINFO $RUNINFO"
ZA=$(echo "$RUNINFO" | awk '{print $8}')
EPOCH=$(echo "$RUNINFO" | awk '{print $1}')
ATM=$(echo "$RUNINFO" | awk '{print $3}')
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg, epoch ${EPOCH}, ATM ${ATM}"
DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGBs/${ANATYPE}/${EPOCH}_ATM${ATM}"
if [[ -z $MODEL_ROOT && ! -d "${DISPDIR}" ]]; then
    echo "Error finding model directory $DISPDIR"
    exit 1
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
        echo "Error: No zenith bin found in $STEREO_PAR for ZA=$ZA"
        exit 1
    fi
    [[ -n $MODEL_ROOT ]] && DISPDIR="$MODEL_ROOT"
    DISPDIR="${DISPDIR}/${BIN_ID}/dispdir_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-stereo"
    OFIL="${ODIR}/${OFIL}.${XGB}_stereo${VARIANT:+_$VARIANT}"
elif [[ "${XGB_TYPE}" == "classification" ]]; then
    DISPDIR="${DISPDIR}/gammahadron_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-classify"
    OFIL="${ODIR}/${OFIL}.${XGB}_gh"
else
    echo "Invalid XGB type: ${XGB_TYPE}"
    exit 1
fi
SMEAR_ARGS=()
if [[ -n $VARIANT ]]; then
    [[ -f $SMEAR_CONFIG ]] || { echo "Error: missing smearing configuration $SMEAR_CONFIG"; exit 1; }
    SMEAR_ARGS=(--smearing_config "$SMEAR_CONFIG")
    [[ ! -e "$OFIL.root" && ! -e "$OFIL.log" ]] || { echo "Error: output exists: $OFIL"; exit 1; }
    mkdir "$OFIL.lock" || { echo "Error: output locked: $OFIL"; exit 1; }
    trap 'rmdir "$OFIL.lock"' EXIT
    [[ ! -e "$OFIL.root" && ! -e "$OFIL.log" ]] || { echo "Error: output exists: $OFIL"; exit 1; }
    if [[ -n ${EVNDISP_APPTAINER:-} ]]; then
        APPTAINER_EXEC=("${APPTAINER_EXEC[@]:0:${#APPTAINER_EXEC[@]}-1}" --bind "$(dirname "$SMEAR_CONFIG"):$(dirname "$SMEAR_CONFIG")" "${EVNDISP_APPTAINER}")
        [[ -n $MODEL_ROOT ]] && APPTAINER_EXEC=("${APPTAINER_EXEC[@]:0:${#APPTAINER_EXEC[@]}-1}" --bind "$MODEL_ROOT:$MODEL_ROOT" "${EVNDISP_APPTAINER}")
    fi
fi
if [[ -n $VARIANT ]]; then
    echo "Smearing configuration SHA256: $(sha256sum "$SMEAR_CONFIG")"
    for model in "${DISPDIR}.joblib.gz" "${DISPDIR}.joblib"; do
        [[ -f $model ]] && sha256sum "$model"
    done
fi
echo "DispXGB directory $DISPDIR"
echo "DispXGB options $XGB"
echo "Output file $OFIL"
OUTPUT_ROOT="$OFIL.root"
[[ -n $VARIANT ]] && OUTPUT_ROOT="$OFIL.tmp.$$.root"
LOGFILE="$OFIL".log
rm -f "$LOGFILE"

if [[ -n "${EVNDISP_APPTAINER:-}" ]]; then
    "${APPTAINER_EXEC[@]}" "$ML_EXEC" \
        --input_file "$MSCW_FILE" \
        --model_prefix "$DISPDIR" \
        --max_cores $MAXCORES "${SMEAR_ARGS[@]}" \
        --output_file "$OUTPUT_ROOT" > "${LOGFILE}" 2>&1
    ML_STATUS=$?
    {
        echo
        echo "Apptainer image:"
        apptainer inspect "$EVNDISP_APPTAINER"
    } >> "${LOGFILE}" 2>&1
else
    $ML_EXEC --input_file "$MSCW_FILE" \
        --model_prefix "$DISPDIR" \
        --max_cores $MAXCORES "${SMEAR_ARGS[@]}" \
        --output_file "$OUTPUT_ROOT" > "${LOGFILE}" 2>&1
    ML_STATUS=$?
fi

if [[ -z "${EVNDISP_APPTAINER:-}" ]]; then
    evndisp_ml_log_environment "${LOGFILE}" "$env_name" "$ENV_SNAPSHOT_DIR" "$ENV_PREFIX"
fi

evndisp_ml_check_apply "$ML_STATUS" "$OUTPUT_ROOT" "$LOGFILE" || exit 1
if [[ -n $VARIANT ]]; then
    ln "$OUTPUT_ROOT" "$OFIL.root" || { rm -f "$OUTPUT_ROOT"; echo "Error: cannot publish $OFIL.root"; exit 1; }
    rm -f "$OUTPUT_ROOT"
fi
