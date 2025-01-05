#!/bin/sh
#
#  set directories for Eventdisplay analysis at DESY
#
if [[ $# < 2 ]]; then
   echo "source ./set_environment.sh <analysis type> <processing type>"
   echo
   echo "Analysis types:  e.g., AP, AP_DISP, TS, NN"
   echo "Processing types: al9, apptainer"
fi

export VERITAS_ANALYSIS_TYPE="${1}"
PROCESS="${2}"
EVNDISPVERSION="v490.7"

# Test for allowed processing types
allowed_processing_types=("apptainer" "apptainer-dev" "al9")
FOUND_PROCESS="FALSE"
for item in $allowed_processing_types
do
    if [[ $item == $PROCESS ]]; then
        FOUND_PROCESS="TRUE"
    fi
done
if [[ $FOUND_PROCESS == "FALSE" ]]; then
    echo "Processing type $PROCESS not allowed"
    return
fi

########################################################################
# host system settings
USERAFSDIR="/afs/ifh.de/group/cta/scratch/$USER"
USERLUSTDIR="/lustre/fs23/group/veritas/users/$USER"
GROUPLUSTDIR="/lustre/fs23/group/veritas"
GROUPDATADDIR="/lustre/fs24/group/veritas"

########################################################################
# data and IRF directories
#
# data directory (VBF files)
export VERITAS_DATA_DIR=${GROUPDATADDIR}
# general auxiliary directory
export VERITAS_EVNDISP_AUX_DIR=${GROUPLUSTDIR}/Eventdisplay_AnalysisFiles/${EVNDISPVERSION}
# pre-processed data products
export VERITAS_PREPROCESSED_DATA_DIR=${GROUPDATADDIR}/shared/processed_data_${EVNDISPVERSION}/
# general IRF production directory
export VERITAS_IRFPRODUCTION_DIR=${GROUPLUSTDIR}/IRFPRODUCTION
# user data
export VERITAS_USER_DATA_DIR=${USERLUSTDIR}
# user log
export VERITAS_USER_LOG_DIR=${USERAFSDIR}/LOGS/VERITAS
# EVENTDISPLAY script directory (this directory)
export EVNDISPSCRIPTS="$(pwd)"

########################################################################
# software settings
export V2DL3SYS=${USERAFSDIR}/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/PreProcessing/V2DL3/
# EVENTDISPLAY using apptainers
if [[ $PROCESS == "apptainer"* ]]; then
    # export EVNDISP_APPTAINER="$VERITAS_DATA_DIR/shared/APPTAINERS/eventdisplay_v4_v490.7-preprocessing-docker-v2.sif"
    export EVNDISP_APPTAINER="$VERITAS_DATA_DIR/shared/APPTAINERS/eventdisplay_v4_v490.7.sif"
    export EVNDISP_ENV="--env VERITAS_DATA_DIR=${VERITAS_DATA_DIR},VERITAS_EVNDISP_AUX_DIR=${VERITAS_EVNDISP_AUX_DIR},VERITAS_USER_DATA_DIR=${VERITAS_USER_DATA_DIR},VERITAS_USER_LOG_DIR=${VERITAS_USER_LOG_DIR}"
    # export EVNDISPSYS="apptainer exec --no-mount /etc/ssh/ssh_known_hosts2 ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
    export EVNDISPSYS="apptainer exec --no-mount bind-paths --cleanenv ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
    # Alma Linux 9 (al9) processing
elif [[ $PROCESS == "al9" ]]; then
    unset EVNDISP_APPTAINER
    TDIR=`pwd`
    export ROOTSYS=/afs/ifh.de/group/cta/cta/software/root/root_v6.30.02.Linux-almalinux9.3-x86_64-gcc11.4/
    export VBFSYS=/afs/ifh.de/group/cta/VERITAS/software/VBF-0.3.4-c17/
    export EVNDISPSYS=${USERAFSDIR}/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/EventDisplay_${EVNDISPVERSION:0:4}-${PROCESS}
    cd $ROOTSYS
    source ./bin/thisroot.sh
    export PATH=$PATH:${VBFSYS}/bin/
    LD_LIBRARY_PATH=$VBFSYS/lib:$LD_LIBRARY_PATH; export LD_LIBRARY_PATH
    export SOFASYS=${EVNDISPSYS}/sofa
    cd ${EVNDISPSYS}
    source ./setObservatory.sh VTS
    cd ${TDIR}
fi
