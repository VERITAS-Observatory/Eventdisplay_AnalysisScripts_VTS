#!/bin/bash
# XGBoost analysis on mscw MC files.

# qsub parameters
# shellcheck disable=SC2034  # SGE resource directives, read by job scheduler
h_cpu=11:59:00; h_vmem=8000M; tmpdir_size=25G

if [ "$#" -lt 3 ]; then
echo "
Run XGBoost disp reconstruction on mscw files

IRF.dispXGB.sh <analysis type> <input file directory> <output directory>

required parameters:

    <analysis type>         analysis type - 'stereo_analysis' or 'classification'

    <input file directory>  directory with input files (will use all *.mscw.root files)

    <output directory>      directory where XGB files are written
"
exit
fi
# Parse command line arguments
XGB_TYPE=$1
INPUTDIR=$2
[[ "$3" ]] && ODIR=$3
XGB="xgb"
ANALYSIS_TYPE="${VERITAS_ANALYSIS_TYPE:0:2}"

echo "XGB analysis type: $XGB_TYPE"

# Read file list
if [[ ! -d "$INPUTDIR" ]]; then
    echo "Error, input directory $INPUTDIR not found, exiting..."
    exit 1
fi
FILES=$(find "$INPUTDIR" -name "*.mscw.root" | sort -u)

NFILES=$(find "$INPUTDIR" -name "*.mscw.root" | wc -l)
if [ "$NFILES" -gt 0 ]; then
    echo "total number of files to analyze: $NFILES"
else
    echo "Error, no input files found in $INPUTDIR"
    exit 1
fi

# make output directory if it doesn't exist
mkdir -p "$ODIR"
echo -e "Output files will be written to:\n $ODIR"

# directory for run scripts
DATE=$(date +"%y%m%d")
LOGDIR="$(dirname "$INPUTDIR")/submit-XGB-${XGB_TYPE}-${DATE}-$(uuidgen)/"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"
rm -f "${LOGDIR}"/x* 2>/dev/null

# Job submission script
SUBSCRIPT="$(dirname "$0")/helper_scripts/IRF.dispXGB_sub"
HELPER_SCRIPTS_DIR="$(cd "$(dirname "$0")/helper_scripts" && pwd)"
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

for FILE in $FILES
do
    echo "Now analysing $FILE"
    FSCRIPT="$LOGDIR/dispXGB-${XGB_TYPE}-$(basename "$FILE" .root)"
    rm -f "$FSCRIPT".sh

    sed -e "s|FFILE|$FILE|" \
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
    if [[ $SUBC == *condor* ]]; then
        "$(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh" "$FSCRIPT.sh" "$h_vmem" "$tmpdir_size"
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs at once:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
    fi
done
