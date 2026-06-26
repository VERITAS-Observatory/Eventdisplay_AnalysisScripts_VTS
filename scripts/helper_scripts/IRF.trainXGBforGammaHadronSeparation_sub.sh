#!/bin/bash
# Train XGB for gamma/hadron separation

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
SIGNALLIST=MSCWSIGNAL
BCKLIST=MSCWBCK
PARA=MODELPARA
EBIN=ENERGYBIN
ODIR=OUTPUTDIR
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
HELPER_SCRIPTS_DIR="HHELPER_SCRIPTS_DIR"
ENV_SNAPSHOT_DIR="EENV_SNAPSHOT_DIR"
P="0.5"
N="5000000"
MAXCORES=NCORES

# temporary (scratch) directory
if [[ -n "$TMPDIR" ]]; then
    TEMPDIR="$TMPDIR"
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

mkdir -p "${ODIR}"
echo -e "Output files will be written to:\n ${ODIR}"

# shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
evndisp_ml_setup_python_cache "$TEMPDIR" "train_gh_ebin${EBIN}"
evndisp_ml_activate_conda "$env_name"

PREFIX="${ODIR}/gammahadron_bdt"
LOGFILE="${PREFIX}_ebin${EBIN}.log"
rm -f "$LOGFILE"

eventdisplay-ml-train-xgb-classify \
    --input_signal_file_list "${SIGNALLIST}" \
    --input_background_file_list "${BCKLIST}" \
    --observatory VERITAS \
    --model_prefix "${PREFIX}" \
    --energy_bin_number "${EBIN}" \
    --model_parameters "${PARA}" \
    --max_cores $MAXCORES \
    --balance_class_zenith_weights \
    --train_test_fraction $P --max_events $N  >| "${LOGFILE}" 2>&1

evndisp_ml_log_environment "${LOGFILE}" "$env_name" "$ENV_SNAPSHOT_DIR"

conda deactivate
