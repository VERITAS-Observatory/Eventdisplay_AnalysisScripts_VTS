#!/bin/bash
# Train XGB for gamma/hadron separation
#

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
SIGNALLIST=MSCWSIGNAL
BCKLIST=MSCWBCK
PARA=MODELPARA
EBIN=ENERGYBIN
TEL=TTYPE
ODIR=OUTPUTDIR
env_name="eventdisplay_ml"
P="0.5"
N="1000000"

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

source activate base
conda activate $env_name

LOGFILE="${ODIR}/XGB_ntel${TEL}_ebin${EBIN}.log"
rm -f "$LOGFILE"

eventdisplay-ml-train-xgb-classify \
    --input_signal_file_list "${SIGNALLIST}" \
    --input_background_file_list "${BCKLIST}" \
    --ntel $TEL \
    --model-prefix "${ODIR}/dispdir_bdt" \
    --energy_bin_number "${EBIN}" \
    --model-parameters "${PARA}" \
    --train_test_fraction $P --max_events $N >| "${LOGFILE}" 2>&1

python --version >> "${LOGFILE}"
conda list -n $env_name >> "${LOGFILE}"

conda deactivate
