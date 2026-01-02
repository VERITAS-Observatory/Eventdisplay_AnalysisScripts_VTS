#!/bin/bash
# Run XGB disp stereo and classification analysis on MC mscw file

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
MSCW_FILE=FFILE
ODIR=OODIR
env_name="eventdisplay_ml"
XGB=XXGB
XGB_TYPE=XGB_TTYPE
ANATYPE=ANALYSISTYPE

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

eval "$(conda shell.bash hook)"
conda activate $env_name

if [[ ! -e ${MSCW_FILE} ]]; then
    echo "File ${MSCW_FILE} not found. Exiting."
    exit
fi
ZA=$(basename "$MSCW_FILE" | cut -d'_' -f1)
ZA=${ZA%deg}
echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg"

RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${MSCW_FILE} -runinfo)
EPOCH=`echo "$RUNINFO" | awk '{print $(1)}'`
ATMO=${FORCEDATMO:-$(echo "$RUNINFO" | awk '{print $3}')}
DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGB/${ANATYPE}/${EPOCH}_ATM${ATMO}/"
if [[ "${XGB_TYPE}" == "stereo_analysis" ]]; then
    if [[ "${ZA}" -lt "38" ]]; then
        DISPDIR="${DISPDIR}/SZE/"
    elif [[ "${ZA}" -lt "48" ]]; then
        DISPDIR="${DISPDIR}/MZE/"
    elif [[ "${ZA}" -lt "58" ]]; then
        DISPDIR="${DISPDIR}/LZE/"
    else
        DISPDIR="${DISPDIR}/XZE/"
    fi
    DISPDIR="${DISPDIR}/dispdir_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-stereo"
elif [[ "${XGB_TYPE}" == "classification" ]]; then
    DISPDIR="${DISPDIR}/gammahadron_bdt"
    ML_EXEC="eventdisplay-ml-apply-xgb-classify"
else
    echo "Invalid XGB type: ${XGB_TYPE}"
    exit
fi
echo "DispXGB directory $DISPDIR"
echo "DispXGB options $XGB"

OFIL=$(basename $MSCW_FILE .root)
OFIL="${ODIR}/${OFIL}.${XGB}"
echo "Output file $OFIL"
LOGFILE="$OFIL".log
rm -f "$LOGFILE"

$ML_EXEC --input_file "$MSCW_FILE" \
    --model_prefix "$DISPDIR" \
    --output_file "$OFIL.root" > "${LOGFILE}" 2>&1

python --version >> "${LOGFILE}"
conda list -n $env_name >> "${LOGFILE}"

conda deactivate
