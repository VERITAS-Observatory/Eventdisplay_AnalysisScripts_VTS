#!/bin/bash
#
#  set directories for Eventdisplay analysis at DESY
#
if (( $# < 2 )); then
   echo "source ./set_environment.sh <analysis type> <processing type> [release]"
   echo
   echo "Analysis types:  e.g., AP, AP_DISP, TS, NN"
   echo "Processing types: al9, apptainer"
   echo "Release: e.g. v490.0, v491.0, v492.0 (default: v492.0)"
   return
fi

PROCESS="${2}"
EVNDISPVERSION="${3:-v492.0}"
if [[ ! $EVNDISPVERSION =~ ^v[0-9]+\.[0-9]+$ ]]; then
    echo "Error: release must look like v492.0." >&2
    return 1
fi
if [[ $PROCESS == apptainer* && $EVNDISPVERSION != v492.0 && -z ${EVNDISP_APPTAINER_IMAGE:-} ]]; then
    echo "Error: set EVNDISP_APPTAINER_IMAGE for release $EVNDISPVERSION." >&2
    return 1
fi

# Test for allowed processing types
allowed_processing_types=("apptainer" "apptainer-dev" "al9")
FOUND_PROCESS="FALSE"
for item in "${allowed_processing_types[@]}";
do
    if [[ $item == "$PROCESS" ]]; then
        FOUND_PROCESS="TRUE"
    fi
done
if [[ $FOUND_PROCESS == "FALSE" ]]; then
    echo "Processing type $PROCESS not allowed"
    return
fi

export VERITAS_ANALYSIS_TYPE="${1}"
release_series=${EVNDISPVERSION%%.*}
if [[ -z ${EVNDISP_ML_ENV:-} || ${EVNDISP_ML_ENV} == "${_EVNDISP_AUTO_ML_ENV:-}" ]]; then
    export EVNDISP_ML_ENV="eventdisplay_ml_${release_series}"
    _EVNDISP_AUTO_ML_ENV="$EVNDISP_ML_ENV"
else
    unset _EVNDISP_AUTO_ML_ENV
fi

########################################################################
# Resolve the sourced script independently of the caller's working directory.
if [[ -n ${ZSH_VERSION:-} ]]; then
    eval 'ENVIRONMENT_SCRIPT=${(%):-%x}'
else
    ENVIRONMENT_SCRIPT=${BASH_SOURCE[0]}
fi
ENVIRONMENT_SCRIPTS_DIR=$(cd "$(dirname "$ENVIRONMENT_SCRIPT")" && pwd) || return 1
PROJECTDIR="${EVNDISP_PROJECT_DIR:-$(cd "$ENVIRONMENT_SCRIPTS_DIR/../.." && pwd)}"
USERLUSTDIR="/lustre/fs23/group/veritas/users/$USER"
GROUPLUSTDIR="/lustre/fs23/group/veritas"
GROUPDATADIR="/lustre/fs24/group/veritas"

########################################################################
# data and IRF directories
#
# data directory (VBF files)
export VERITAS_DATA_DIR=${GROUPDATADIR}
# data directory for simulations (dCache)
export VERITAS_DCACHE_DIR="/pnfs/ifh.de/acs/veritas/archive/"
# general auxiliary directory
export VERITAS_EVNDISP_AUX_DIR=${GROUPLUSTDIR}/Eventdisplay_AnalysisFiles/${EVNDISPVERSION}
# pre-processed data products
export VERITAS_PREPROCESSED_DATA_DIR=${GROUPDATADIR}/shared/processed_data_${EVNDISPVERSION}/
# general IRF production directory
export VERITAS_IRFPRODUCTION_DIR=${GROUPLUSTDIR}/IRFPRODUCTION
# user data
export VERITAS_USER_DATA_DIR=${USERLUSTDIR}
# user log
export VERITAS_USER_LOG_DIR=${USERLUSTDIR}/LOGS/VERITAS
# EVENTDISPLAY script directory (this directory)
export EVNDISPSCRIPTS="$ENVIRONMENT_SCRIPTS_DIR"

########################################################################
# software settings
export V2DL3SYS="${PROJECTDIR}/V2DL3"
export EVNDISP_ML_SYS="${PROJECTDIR}/Eventdisplay-ML"
# EVENTDISPLAY using apptainers
if [[ $PROCESS == "apptainer"* ]]; then
    export EVNDISP_APPTAINER="${EVNDISP_APPTAINER_IMAGE:-$VERITAS_DATA_DIR/shared/APPTAINERS/eventdisplay_v4_${EVNDISPVERSION}-rc8.sif}"
    export EVNDISP_ENV="--env VERITAS_DATA_DIR=${VERITAS_DATA_DIR},VERITAS_EVNDISP_AUX_DIR=${VERITAS_EVNDISP_AUX_DIR},VERITAS_USER_DATA_DIR=${VERITAS_USER_DATA_DIR},VERITAS_USER_LOG_DIR=${VERITAS_USER_LOG_DIR}"
    export EVNDISPSYS="apptainer exec --no-mount bind-paths --cleanenv ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
    # Alma Linux 9 (al9) processing
elif [[ $PROCESS == "al9" ]]; then
    unset EVNDISP_APPTAINER
    TDIR=$(pwd)
    export ROOTSYS=/afs/ifh.de/group/cta/cta/software/root/root_v6.40.00.Linux-almalinux9.7-x86_64-gcc11.5
    export VBFSYS=/afs/ifh.de/group/cta/VERITAS/software/VBF-0.3.4-c17/
    export EVNDISPSYS="${PROJECTDIR}/EventDisplay_v4"
    cd "$ROOTSYS" || return
# shellcheck source=/dev/null
    source ./bin/thisroot.sh
    export PATH=$PATH:${VBFSYS}/bin/
    export LD_LIBRARY_PATH="$VBFSYS/lib:$LD_LIBRARY_PATH"
    export SOFASYS=${EVNDISPSYS}/sofa
    cd "${EVNDISPSYS}" || return
# shellcheck source=/dev/null
    source ./setObservatory.sh VTS
    cd "${TDIR}" || return
fi
