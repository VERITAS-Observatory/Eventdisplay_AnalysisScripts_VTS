#!/bin/bash
# script to optimize BDT cuts
#
#

h_cpu=11:59:59; h_vmem=4000M; tmpdir_size=1G

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

    <atmosphere>                    atmosphere model(s) (61 = winter, 62 = summer)

--------------------------------------------------------------------------------
"
#end help message
exit
fi
echo " "
# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
PREDIR=$1
CUTTYPE=$2
SIMTYPE=$3
EPOCH=$4
ATM=$5
# evndisplay version
IRFVERSION=`$EVNDISPSYS/bin/trainTMVAforGammaHadronSeparation --version | tr -d .| sed -e 's/[a-Z]*$//'`

DISPBDT=""
ANATYPE="AP"
if [[ ! -z $VERITAS_ANALYSIS_TYPE ]]; then
    ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
    if [[ ${VERITAS_ANALYSIS_TYPE} == *"DISP"* ]]; then
        DISPBDT="_DISP"
    fi 
fi

# Check that list of background files exists
if [[ ! -d "${PREDIR}/${CUTTYPE}" ]]; then
    echo "Error, directory with background files ${PREDIR}/${CUTTYPE} not found, exiting..."
    exit 1
fi

#####################################
# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$PREDIR/${CUTTYPE}/$DATE/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p $LOGDIR

# EffAreaFile
if [[ $CUTTYPE == *"Moderate"* ]]; then
    EFFFILE=effArea-v490-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-Moderate-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == *"SuperSoft"* ]]; then
    EFFFILE=effArea-v490-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-SuperSoft-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == *"Soft"* ]]; then
    EFFFILE=effArea-v490-auxv01-${SIMTYPE}-Cut-NTel2-PointSource-Soft-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
elif [[ $CUTTYPE == *"Hard"* ]]; then
    EFFFILE=effArea-v490-auxv01-${SIMTYPE}-Cut-NTel3-PointSource-Hard-TMVA-Preselection-${VERITAS_ANALYSIS_TYPE/_/-}-${EPOCH}-ATM${ATM}-T1234.root
fi

if [[ ! -e $VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFFILE} ]]; then
    echo "Error - effective area file not found ${EFFFILE}"
fi
if [[ ${EPOCH:0:2} == "V4" ]] || [[ ${EPOCH:0:2} == "V5" ]]; then
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/TMVA.BDT.V4.runparameter"
else
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/TMVA.BDT.runparameter"
fi
#####################################
# energy bins
if grep -q "^* ENERGYBINS" "$RUNPAR"; then
    ENBINS=$( cat "$RUNPAR" | grep "^* ENERGYBINS 1" | sed -e 's/* ENERGYBINS 1//' | sed -e 's/ /\n/g')
    declare -a EBINARRAY=( $ENBINS ) #convert to array
    count1=1
    NENE=$((${#EBINARRAY[@]}-$count1)) #get number of bins
    for (( i=0; i < $NENE; i++ ))
    do
        EBINMIN[$i]=${EBINARRAY[$i]}
        EBINMAX[$i]=${EBINARRAY[$i+1]}
    done
else
    ENBINS=$( cat "$RUNPAR" | grep "^* ENERGYBINEDGES" | sed -e 's/* ENERGYBINEDGES//' | sed -e 's/ /\n/g')
    declare -a EBINARRAY=( $ENBINS ) #convert to array
    count1=1
    NENE=$((${#EBINARRAY[@]}-$count1)) #get number of bins
    z="0"
    for (( i=0; i < $NENE; i+=2 ))
    do
        EBINMIN[$z]=${EBINARRAY[$i]}
        EBINMAX[$z]=${EBINARRAY[$i+1]}
        let "z = ${z} + 1"
    done
    NENE=$((${#EBINMAX[@]}))
fi

#####################################
# zenith angle bins
ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-$count1)) #get number of bins

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.optimizeTMVAforGammaHadronSeparation_sub"

FSCRIPT="$LOGDIR/IRF.optimizeTMVAforGammaHadronSeparation_sub_${EPOCH}_ATM${ATM}"
sed -e "s|EFFFILE|$EFFFILE|"  \
    -e "s|ODIR|$PREDIR|" \
    -e "s|EEPOCH|${EPOCH}|" \
    -e "s|AATM|${ATM}|" \
    -e "s|EEBINS|${NENE}|" \
    -e "s|ZZBINS|${NZEW}|" \
    -e "s|TMVARUNPARA|${RUNPAR}|" \
    -e "s|CUTTYPE|${CUTTYPE}|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x $FSCRIPT.sh
echo $FSCRIPT.sh

# run locally or on cluster
SUBC=`$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo $SUBC
    exit
fi
if [[ $SUBC == *qsub* ]]; then
 JOBID=`$SUBC $FSCRIPT.sh`
 # account for -terse changing the job number format
 if [[ $SUBC != *-terse* ]] ; then
    echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
    JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
 fi
 echo "JOBID:  $JOBID"
elif [[ $SUBC == *condor* ]]; then
   $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
   condor_submit $FSCRIPT.sh.condor
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT.sh
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
    cat $LOGDIR/runscripts.dat | $SUBC
elif [[ "$SUBC" == *simple* ]] ; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi

exit
