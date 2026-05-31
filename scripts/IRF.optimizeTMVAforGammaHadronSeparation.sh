#!/bin/bash
# script to optimize BDT cuts
#
#

# shellcheck disable=SC2034  # SGE resource directives, read by job scheduler
h_cpu=11:59:59; h_vmem=4000M; tmpdir_size=1G
# shellcheck source=scripts/helper_scripts/UTILITY.submitJob.sh
source "$(dirname "$0")/helper_scripts/UTILITY.submitJob.sh"

if [[ $# -lt 5 ]]; then
# begin help message
echo "
Optimize BDT cuts for TMVA with signal rates from MC and background rates from data.

IRF.optimizeTMVAforGammaHadronSeparation.sh <preselection results directory> <cut type> <sim type> <epoch> <atmosphere>

required parameters:

    <preselection results directory>     directory with preselection results

    <cut type>                      preselection cut type (e.g., NTel2-Moderate)

    <sim type>                      simulation type (e.g. GRISU, CARE_June2020)

    <epoch>                         array epoch e.g. V4, V5, V6, V6_2012_2013a

    <atmosphere>                    atmosphere model (61 = winter, 62 = summer)

--------------------------------------------------------------------------------
"
#end help message
exit
fi
echo " "
# Run init script
bash "$(dirname "$0")/helper_scripts/UTILITY.script_init.sh" || exit 1

# Parse command line arguments
PREDIR=$1
CUTTYPE=$2
SIMTYPE=$3
EPOCH=$4
ATM=$5
# evndisplay version
IRFVERSION=$(cat "$VERITAS_EVNDISP_AUX_DIR"/IRFVERSION)

# Check that list of background files exists
if [[ ! -d "${PREDIR}/${CUTTYPE}" ]]; then
    echo "Error, directory with background files ${PREDIR}/${CUTTYPE} not found, exiting..."
    exit 1
fi

#####################################
# directory for run scripts
DATE=$(date +"%y%m%d")
LOGDIR="$PREDIR/${CUTTYPE}/$DATE/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# EffAreaFile
if [[ $CUTTYPE == *"Moderate"* ]]; then
    EFFFILE=effArea-${IRFVERSION}-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-Moderate-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == *"SuperSoft"* ]]; then
    EFFFILE=effArea-${IRFVERSION}-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-SuperSoft-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == *"Soft"* ]]; then
    EFFFILE=effArea-${IRFVERSION}-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-Soft-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == NTel3*"Hard"* ]]; then
    EFFFILE=effArea-${IRFVERSION}-auxv01-${SIMTYPE}-Cut-NTel3-PointSource-Hard-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == NTel2*"Hard"* ]]; then
    EFFFILE=effArea-${IRFVERSION}-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-Hard-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
fi

if [[ ! -e $VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFFILE} ]]; then
    echo "Error - effective area file not found ${EFFFILE}"
    exit 1
fi
if [[ ${EPOCH:0:2} == "V4" ]] || [[ ${EPOCH:0:2} == "V5" ]]; then
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/TMVA.BDT.V4.runparameter"
else
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/TMVA.BDT.runparameter"
fi
#####################################
# energy bins
count1=1
if grep -q "^\* ENERGYBINS" "$RUNPAR"; then
    ENBINS=$( cat "$RUNPAR" | grep "^\* ENERGYBINS" | sed -e 's/\* ENERGYBINS//' | sed -e 's/ /\n/g')
    mapfile -t EBINARRAY <<< "$ENBINS"
    NENE=$(( ${#EBINARRAY[@]}-count1 )) #get number of bins
else
    ENBINS=$( cat "$RUNPAR" | grep "^* ENERGYBINEDGES" | sed -e 's/* ENERGYBINEDGES//' | sed -e 's/ /\n/g')
    mapfile -t EBINARRAY <<< "$ENBINS"
    NENE=$(( ${#EBINARRAY[@]} / 2 ))
fi

#####################################
# zenith angle bins
ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
mapfile -t ZEBINARRAY <<< "$ZEBINS"
NZEW=$(( ${#ZEBINARRAY[@]}-count1 )) #get number of bins

# Job submission script
SUBSCRIPT="$(dirname "$0")/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub"

FSCRIPT="$LOGDIR/IRF.optimizeTMVAforGammaHadronSeparation_sub_${EPOCH}_ATM${ATM}"
sed -e "s|EFFFILE|$EFFFILE|"  \
    -e "s|ODIR|$PREDIR|" \
    -e "s|EEPOCH|${EPOCH}|" \
    -e "s|AATM|${ATM}|" \
    -e "s|EEBINS|${NENE}|" \
    -e "s|ZZBINS|${NZEW}|" \
    -e "s|TMVARUNPARA|${RUNPAR}|" \
    -e "s|CUTTYPE|${CUTTYPE}|" "$SUBSCRIPT".sh > "$FSCRIPT".sh

chmod u+x "$FSCRIPT".sh
echo "$FSCRIPT".sh

# run locally or on cluster
SUBC=$("$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh")
SUBC=$(eval "echo \"$SUBC\"")
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
submit_job "$FSCRIPT.sh" "$FSCRIPT.sh &> $FSCRIPT.log" "$LOGDIR/runscripts.dat"
if [[ $SUBC == *qsub* ]]; then
 echo "JOBID:  $JOBID"
fi
run_parallel_jobs "$LOGDIR/runscripts.dat"
