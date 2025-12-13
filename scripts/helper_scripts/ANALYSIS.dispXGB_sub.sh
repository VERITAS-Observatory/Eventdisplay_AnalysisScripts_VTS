#!/bin/bash
# Run XGB disp direction analysis on mscw file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
RUN=RRUN
ODIR=OODIR
env_name="eventdisplay_v4"
XGB="XXGB"

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

source activate base
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
ZA=$($EVNDISPSYS/bin/printRunParameter ${MSCW_FILE} -elevation | awk '{print $3}')
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg"

DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGB/AP/V6_2016_2017_ATM61/"
if (( $(echo "90.-$ZA < 38" |bc -l) )); then
    DISPDIR="${DISPDIR}/SZE/"
elif (( $(echo "90.-$ZA < 48" |bc -l) )); then
    DISPDIR="${DISPDIR}/MZE/"
elif (( $(echo "90.-$ZA < 58" |bc -l) )); then
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
python $EVNDISPSYS/python/applyXGBoostforDirection.py \
    "$MSCW_FILE" \
    "$DISPDIR" \
    "$OFIL.root" > "$OFIL.log" 2>&1

python --version >> "${OFIL}.log"
conda list -n $env_name >> "${OFIL}.log"

conda deactivate
