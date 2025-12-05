#!/bin/bash
# Train XGB disp direction analysis using MC mscw file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
LLIST=MSCWLIST
TEL=TTYPE
ODIR=OUTPUTDIR
env_name="eventdisplay_v4"
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

# make output directory if it doesn't exist
mkdir -p ${ODIR}
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

OFIL="${ODIR}/XGB_ntel${TEL}.log"
rm -f "$OFIL".log

cd $EVNDISPSYS
python $EVNDISPSYS/src/trainXGBoostforDirection.py $LLIST $TEL ${ODIR} $P $N >| ${OFIL} 2>&1

python --version >> "${OFIL}.log"
conda list -n $env_name >> "${OFIL}.log"

conda deactivate
