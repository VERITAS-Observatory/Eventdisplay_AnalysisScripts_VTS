#!/bin/bash
# XGBoost analysis on mscw data files.

# qsub parameters
# shellcheck disable=SC2034  # SGE resource directives, read by job scheduler
h_cpu=11:59:00; h_vmem=4000M; tmpdir_size=25G
# shellcheck source=scripts/helper_scripts/UTILITY.submitJob.sh
source "$(dirname "$0")/helper_scripts/UTILITY.submitJob.sh"

if [ "$#" -lt 3 ]; then
echo "
Run XGBoost disp reconstruction on mscw files

ANALYSIS.dispXGB.sh <analysis type> <run list> <output directory>

required parameters:

    <analysis type>         analysis type - 'stereo_analysis' or 'classification'

    <runlist>               run list with one run number per line.

    <output directory>      directory where XGB files are written
"
exit
fi
# Parse command line arguments
XGB_TYPE=$1
RUNLIST=$2
[[ "$3" ]] && ODIR=$3
XGB="xgb"
ANALYSIS_TYPE="${VERITAS_ANALYSIS_TYPE:0:2}"

echo "XGB analysis type: $XGB_TYPE"

# Read run list
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, runlist $RUNLIST not found, exiting..."
    exit 1
fi
FILES=$(cat "$RUNLIST")

NFILES=$(cat "$RUNLIST" | wc -l)
if [ "$NFILES" -gt 0 ]; then
    echo "total number of files to analyze: $NFILES"
else
    echo "Error, no input files found in $RUNLIST"
    exit 1
fi

# make output directory if it doesn't exist
mkdir -p "$ODIR"
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=$(date +"%y%m%d")
LOGDIR="$VERITAS_USER_LOG_DIR/XGB-${XGB_TYPE}-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f "${LOGDIR}"/x* 2>/dev/null

# Job submission script
SUBSCRIPT="$(dirname "$0")/helper_scripts/ANALYSIS.dispXGB_sub"
HELPER_SCRIPTS_DIR="$(cd "$(dirname "$0")/helper_scripts" && pwd)"
TIMETAG=$(date +"%s")
CREATED_LOGSUBDIRS=" "
env_name="${EVNDISP_ML_ENV:-eventdisplay_ml}"
ENV_PREFIX=""

if [[ -z "${EVNDISP_APPTAINER:-}" ]]; then
    # shellcheck source=scripts/helper_scripts/UTILITY.conda_env.sh
    source "${HELPER_SCRIPTS_DIR}/UTILITY.conda_env.sh"
    ENV_PREFIX="$(evndisp_ml_resolve_env_prefix "$env_name")" || {
        echo "Error: failed to resolve conda environment '$env_name'."
        exit 1
    }
    echo "Using Eventdisplay-ML conda environment '$env_name' at '$ENV_PREFIX'"
fi

for RUNN in $FILES
do
    echo "Now analysing run $RUNN"
    if [[ ${RUNN:0:1} =~ [6-9] ]]; then
        LOGSUBDIR="0${RUNN:0:1}"
    else
        LOGSUBDIR="${RUNN:0:2}"
    fi
    if [[ $CREATED_LOGSUBDIRS != *" $LOGSUBDIR "* ]]; then
        mkdir -p "$LOGDIR/$LOGSUBDIR"
        CREATED_LOGSUBDIRS+="$LOGSUBDIR "
    fi
    FSCRIPT="$LOGDIR/$LOGSUBDIR/dispXGB-${XGB_TYPE}-$RUNN"
    rm -f "$FSCRIPT".sh

    sed -e "s|RRUN|$RUNN|" \
        -e "s|XXGB|$XGB|" \
        -e "s|XGB_TTYPE|$XGB_TYPE|" \
        -e "s|ANALYSISTYPE|$ANALYSIS_TYPE|" \
        -e "s|HHELPER_SCRIPTS_DIR|$HELPER_SCRIPTS_DIR|" \
        -e "s|CCONDA_ENV_PREFIX|$ENV_PREFIX|" \
        -e "s|EENV_SNAPSHOT_DIR|$LOGDIR|" \
        -e "s|OODIR|$ODIR|" "$SUBSCRIPT".sh > "$FSCRIPT".sh

    chmod u+x "$FSCRIPT.sh"
    echo "$FSCRIPT".sh

    SUBC=$("$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh")
    SUBC=$(eval "echo \"$SUBC\"")
    submit_job "$FSCRIPT.sh" "$FSCRIPT.sh &> $FSCRIPT.log" "${LOGDIR}/runscripts.$TIMETAG.dat"
    if [[ $SUBC == *parallel* ]]; then
        echo "RUN $RUNN OLOG $FSCRIPT.log"
    fi
done
