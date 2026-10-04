#!/bin/bash
# Train XGB disp direction analysis using MC mscw file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
LLIST=MSCWLIST
ODIR=OUTPUTDIR
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
HELPER_SCRIPTS_DIR="HHELPER_SCRIPTS_DIR"
ENV_SNAPSHOT_DIR="EENV_SNAPSHOT_DIR"
P="0.5"
N="5000000"
MAXCORES=NCORES

# temporary (scratch) directory
TEMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/trainXGBforAngularReconstruction_sub-XXXXXX") || exit 1
trap 'rm -rf -- "$TEMPDIR"' EXIT
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

mkdir -p "${ODIR}" || exit 1
echo -e "Output files will be written to:\n ${ODIR}"

# shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
evndisp_ml_setup_python_cache "$TEMPDIR" "train_stereo_$(basename "$LLIST" .list)"
evndisp_ml_activate_conda "$env_name"

PREFIX="${ODIR}/dispdir_bdt"
LOGFILE="${PREFIX}.log"
rm -f "$LOGFILE"

eventdisplay-ml-train-xgb-stereo \
    --input_file_list "$LLIST" \
    --model_prefix "${PREFIX}" \
    --max_cores $MAXCORES \
    --observatory VERITAS \
    --min_images 2 --memory_profile \
    --train_test_fraction $P --max_events $N >| "${LOGFILE}" 2>&1

evndisp_ml_log_environment "${LOGFILE}" "$env_name" "$ENV_SNAPSHOT_DIR"

conda deactivate
