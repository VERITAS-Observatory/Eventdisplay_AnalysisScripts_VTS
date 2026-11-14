#!/bin/bash
# Train XGB disp direction analysis using MC mscw file

# Don't do set -e: the environment is logged after the ML step.
# The ML exit status is checked explicitly (evndisp_ml_check_train).

# parameters replaced by parent script using sed
LLIST=MSCWLIST
ODIR=OUTPUTDIR
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
HELPER_SCRIPTS_DIR="HHELPER_SCRIPTS_DIR"
ENV_SNAPSHOT_DIR="EENV_SNAPSHOT_DIR"
VARIANT="VVARIANT"
SMEAR_CONFIG="SSMEAR_CONFIG"
P="0.5"
N="5000000"
MAXCORES=NCORES

# temporary (scratch) directory
if [[ -n "$TMPDIR" ]]; then
    TEMPDIR="${TMPDIR}/XGB-$(basename "$LLIST" .list)-$(uuidgen)"
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

mkdir -p "${ODIR}" || exit 1
echo -e "Output files will be written to:\n ${ODIR}"

# shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
# shellcheck source=scripts/helper_scripts/UTILITY.xgb_checks.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.xgb_checks.sh"
evndisp_ml_setup_python_cache "$TEMPDIR" "train_stereo_$(basename "$LLIST" .list)"
evndisp_ml_activate_conda "$env_name"

PREFIX="${ODIR}/dispdir_bdt"
SMEAR_ARGS=()
if [[ -n $VARIANT ]]; then
    SMEAR_ARGS=(--smearing_config "$SMEAR_CONFIG")
    [[ ! -e "${PREFIX}.joblib.gz" && ! -e "${PREFIX}.joblib" && ! -e "${PREFIX}.log" ]] || { echo "Error: training output exists: $PREFIX"; exit 1; }
    mkdir "${PREFIX}.lock" || { echo "Error: training output locked: $PREFIX"; exit 1; }
    trap 'rmdir "${PREFIX}.lock"' EXIT
    [[ ! -e "${PREFIX}.joblib.gz" && ! -e "${PREFIX}.joblib" && ! -e "${PREFIX}.log" ]] || exit 1
fi
LOGFILE="${PREFIX}.log"
rm -f "$LOGFILE"

eventdisplay-ml-train-xgb-stereo \
    --input_file_list "$LLIST" \
    --model_prefix "${PREFIX}" \
    --max_cores $MAXCORES \
    --observatory VERITAS \
    --min_images 2 --memory_profile "${SMEAR_ARGS[@]}" \
    --train_test_fraction $P --max_events $N >| "${LOGFILE}" 2>&1
ML_STATUS=$?

evndisp_ml_log_environment "${LOGFILE}" "$env_name" "$ENV_SNAPSHOT_DIR"

conda deactivate

evndisp_ml_check_train "$ML_STATUS" "${PREFIX}" "$LOGFILE" || exit 1
