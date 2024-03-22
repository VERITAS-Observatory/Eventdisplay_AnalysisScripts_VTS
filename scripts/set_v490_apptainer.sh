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

########################################################################
# data and IRF directories

# analysis type
export VERITAS_ANALYSIS_TYPE=${1}
# data directory (VBF files)
export VERITAS_DATA_DIR=${GROUPDATADDIR}
# general auxiliary directory
export VERITAS_EVNDISP_AUX_DIR=${GROUPLUSTDIR}/Eventdisplay_AnalysisFiles/${EVNDISPVERSION}-prepocessing
# pre-processed data products
export VERITAS_PREPROCESSED_DATA_DIR=${GROUPDATADDIR}/shared/processed_data_${EVNDISPVERSION:0:4}.7/
# user IRF production directory
export VERITAS_IRFPRODUCTION_DIR=${GROUPLUSTDIR}/IRFPRODUCTION
# user data
export VERITAS_USER_DATA_DIR=${USERLUSTDIR}
# user log
export VERITAS_USER_LOG_DIR=${USERAFSDIR}/LOGS/VERITAS

## EVENTDISPLAY using apptainers
export EVNDISP_APPTAINER="$VERITAS_DATA_DIR/shared/APPTAINERS/eventdisplay_v4_v490.7-preprocessing-docker-v2.sif"
export EVNDISP_ENV="--env VERITAS_DATA_DIR=${VERITAS_DATA_DIR},VERITAS_EVNDISP_AUX_DIR=${VERITAS_EVNDISP_AUX_DIR},VERITAS_USER_DATA_DIR=${VERITAS_USER_DATA_DIR},VERITAS_USER_LOG_DIR=${VERITAS_USER_LOG_DIR}"
# export EVNDISPSYS="apptainer exec --no-mount /etc/ssh/ssh_known_hosts2 ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
export EVNDISPSYS="apptainer exec --no-mount bind-paths --cleanenv ${EVNDISP_APPTAINER} /opt/EventDisplay_v4/"
export EVNDISPSCRIPTS=${USERAFSDIR}/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/PreProcessing/Eventdisplay_AnalysisScripts_VTS_${EVNDISPVERSION}/scripts
export V2DL3SYS=${USERAFSDIR}/EVNDISP/EVNDISP-400/GITHUB_Eventdisplay/PreProcessing/V2DL3/
