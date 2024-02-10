#!/bin/sh
#
#  set directories for Eventdisplay v4 analysis at DESY
#  This is for using Apptainers
#
#
if [[ $# < 1 ]]; then
   echo "source ./set_v490.sh <analysis type>"
   echo
   echo "   e.g., AP, AP_DISP, TS, NN"
fi

EVNDISPVERSION="v490.7"
USERAFSDIR="/afs/ifh.de/group/cta/scratch/$USER"
USERLUSTDIR="/lustre/fs23/group/veritas/users/$USER"
GROUPLUSTDIR="/lustre/fs23/group/veritas"
GROUPDATADDIR="/lustre/fs24/group/veritas"
export EVNDISP_APPTAINER="/lustre/fs24/group/veritas/shared/APPTAINERS/eventdisplay_v4_v490.7-preprocessing-docker.sif"

########################################################################
# data and IRF directories

# analysis type
export VERITAS_ANALYSIS_TYPE=${1}
# data directory (VBF files)
export VERITAS_DATA_DIR=${GROUPDATADDIR}
# general auxiliary directory
export VERITAS_EVNDISP_AUX_DIR=${GROUPLUSTDIR}/Eventdisplay_AnalysisFiles/${EVNDISPVERSION}/
# user IRF production directory
export VERITAS_IRFPRODUCTION_DIR=${GROUPLUSTDIR}/IRFPRODUCTION
# user data
export VERITAS_USER_DATA_DIR=${USERLUSTDIR}
# user log
export VERITAS_USER_LOG_DIR=${USERAFSDIR}/LOGS/VERITAS

## EVENTDISPLAY using apptainers
export EVNDISP_ENV="--env VERITAS_DATA_DIR=${VERITAS_DATA_DIR},VERITAS_EVNDISP_AUX_DIR=${VERITAS_EVNDISP_AUX_DIR},VERITAS_USER_DATA_DIR=${VERITAS_USER_DATA_DIR},VERITAS_USER_LOG_DIR=${VERITAS_USER_LOG_DIR}"
# export EVNDISPSYS="apptainer exec --no-mount /etc/ssh/ssh_known_hosts2 ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
export EVNDISPSYS="apptainer exec --no-mount bind-paths --cleanenv ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
export EVNDISPSCRIPTS=${USERAFSDIR}/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/PreProcessing/Eventdisplay_AnalysisScripts_VTS_${EVNDISPVERSION}/scripts
