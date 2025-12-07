#!/bin/bash
# Run XGB disp direction analysis on MC mscw file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
MSCW_FILE=FFILE
ODIR=OODIR
env_name="eventdisplay_v4"
XGB=XXGB

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

if [[ ! -e ${MSCW_FILE} ]]; then
    echo "File ${MSCW_FILE} not found. Exiting."
    exit
fi
ZA=$(basename "$MSCW_FILE" | cut -d'_' -f1)
ZA=${ZA%deg}
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg"

DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGB/AP/V6_2016_2017_ATM61/"
if (( $(echo "90-$ZA < 38" |bc -l) )); then
    DISPDIR="${DISPDIR}/SZE/"
elif (( $(echo "90-$ZA < 48" |bc -l) )); then
    DISPDIR="${DISPDIR}/MZE/"
elif (( $(echo "90-$ZA < 58" |bc -l) )); then
    DISPDIR="${DISPDIR}/LZE/"
else
    DISPDIR="${DISPDIR}/XZE/"
fi
echo "DispXGB directory $DISPDIR"
echo "DispXGB options $XGB"

OFIL=$(basename $MSCW_FILE .root)
OFIL="${ODIR}/${OFIL}.${XGB}"
echo "Output file $OFIL"

rm -f "$OFIL".log

cd $EVNDISPSYS
python src/applyXGBoostforDirection.py "$MSCW_FILE" "$DISPDIR" "$OFIL.root" > "$OFIL.log" 2>&1

python --version >> "${OFIL}.log"
conda list -n $env_name >> "${OFIL}.log"

conda deactivate
