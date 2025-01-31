#!/bin/bash
# submit evndisp for grisu/care simulations

# qsub parameters
h_cpu=47:59:00; h_vmem=8000M; tmpdir_size=250G
DATE=$(date +"%y%m%d")

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 7 ]; then
echo "
IRF generation: analyze simulation VBF files using evndisp

IRF.evndisp_MC.sh <sim directory> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <sim type> <runparameter file>  [particle] [analysis type] [uuid]

required parameters:

    <sim directory>         directory containing simulation VBF files

    <epoch>                 array epoch (e.g., V4, V5, V6)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]

    <sim type>              file simulation type (e.g. GRISU, CARE_June1425)

    <runparameter file>     file with integration window size and reconstruction cuts/methods,
                            expected in $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/


optional parameters:

    [particle]              type of particle used in simulation:
                            gamma = 1, electron = 2, proton = 14, helium = 402
                            (default = 1  -->  gamma)

    [analysis type]         type of analysis (default="")

    [uuid]                  UUID used for submit directory

Note: zenith angles, wobble offsets, and noise values are hard-coded into script

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ -z "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1


SIMDIR="$1"
EPOCH="$2"
ATM="$3"
ZA="$4"
WOBBLE="$5"
NOISE="$6"
SIMTYPE="$7"
ACUTS=${8:-"EVNDISP.reconstruction.runparameter"}
PARTICLE=${9:-1}
ANALYSIS_TYPE=${10:-""}
UUID=${11:-"${DATE}-$(uuidgen)"}

# Particle names
declare -A PARTICLE_NAMES=( [1]="gamma" [2]="electron" [14]="proton" [402]="alpha" )
PARTICLE_TYPE="${PARTICLE_NAMES[$PARTICLE]}"

echo "IRF.evndisp_MC.sh for epoch $EPOCH, atmo $ATM, zenith $ZA, wobble $WOBBLE, noise $NOISE (Analysis type: $ANALYSIS_TYPE)"

if [[ -z $VERITAS_IRFPRODUCTION_DIR || -z $VERITAS_EVNDISP_AUX_DIR ]]; then
    echo "Error: environment variables VERITAS_IRFPRODUCTION_DIR or VERITAS_EVNDISP_AUX_DIR are not set."
    exit 1
fi
ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
LOGDIR="$ODIR/submit-EVNDISP-${UUID}"
OPDIR="$ODIR/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
mkdir -p "$OPDIR" "$LOGDIR"
chmod -R g+w "$OPDIR"
echo "Output: $OPDIR"
echo "Logs: $LOGDIR"
echo "Sims: $SIMDIR"
echo "Runparameter: $ACUTS Simulation type:$SIMTYPE"

# Analysis options
EDOPTIONS=""
if [[ ${ANALYSIS_TYPE} == *"SQ2"* ]]; then
   EDOPTIONS="-imagesquared"
fi

# Create a unique set of run numbers
if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="946500"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="956500"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="966500"
elif [ ${SIMTYPE:0:4} == "CARE" ]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="941200"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="951200"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="961200"
fi

INT_WOBBLE=$(echo "$WOBBLE*100" | bc | awk -F '.' '{print $1}')
if [[ ${#INT_WOBBLE} -lt 2 ]]; then
   INT_WOBBLE="000"
elif [[ ${#INT_WOBBLE} -lt 3 ]]; then
   INT_WOBBLE="0$INT_WOBBLE"
fi

#######################################################
# Find simulation file depending on the type of simulations
# GRISU simulations (requires noise file)
NOISEFILE="NO_NOISEFILE"
if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
    if [[ ${EPOCH:0:2} == "V4" ]] || [[ ${EPOCH:0:2} == "V5" ]]; then
        if [[ ${EPOCH:0:2} == "V5" ]]; then
            VBFFILENAME="gamma_V5_Oct2012_newArrayConfig_20121027_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*"
        elif [[ $ATM == "21" ]]; then
            VBFFILENAME="Oct2012_oa_ATM21_${ZA}deg_${INT_WOBBLE}*"
        else
            VBFFILENAME="gamma_V4_Oct2012_SummerV4ForProcessing_20130611_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*"
        fi
        NOISEFILE="$VERITAS_EVNDISP_AUX_DIR/NOISE/NOISE$NOISE.grisu"
    elif [[ ${EPOCH:0:2} == "V6" ]]; then
        if [[ $ATM == "21-redHV" ]]; then
            VBFFILENAME="gamma_V6_Upgrade_ReducedHV_20121211_v420_ATM21_${ZA}deg_${INT_WOBBLE}*"
        elif [[ $ATM == "21-UV" ]]; then
            VBFFILENAME="gamma_V6_Upgrade_UVfilters_20121211_v420_ATM21_${ZA}deg_${INT_WOBBLE}*"
        elif [[ $ATM == "21-SNR" ]]; then
            VBFFILENAME="gamma_V6_201304_SN2013ak_v420_ATM21_${ZA}deg_${INT_WOBBLE}*"
        else
            VBFFILENAME="gamma_V6_Upgrade_20121127_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*"
        fi
        NOISEFILE="$VERITAS_EVNDISP_AUX_DIR/NOISE/NOISE${NOISE}_20120827_v420.grisu"
    fi
#######################################################
elif [ ${SIMTYPE} == "CARE_UV_June1409" ]; then
    # example gamma_00deg_750m_0.5wob_180mhz_up_ATM21_part0.cvbf.bz2
    WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%03d",100*WB) }')
    VBFFILENAME="gamma_${ZA}deg_750m_${WOFFSET}wob_${NOISE}mhz_up_ATM${ATM}_part0.cvbf.bz2"
elif [ ${SIMTYPE} == "CARE_UV_2212" ]; then
    # example gamma_V6_CARE_uvf_Atmosphere61_zen20deg_0.25wob_120MHz.vbf.zst
    VBFILENAME="gamma_V6_CARE_uvf_Atmosphere${ATM}_zen${ZA}deg_${WOBBLE}wob_${NOISE}MHz*.zst"
elif [ ${SIMTYPE} == "CARE_RedHV" ]; then
    # example gamma_V6_PMTUpgrade_RHV_CARE_v1.6.2_12_ATM61_zen40deg_050wob_150MHz.cvbf.zst
    if [[ ${ATM} == 61 ]]; then
        LBL="PMTUpgrade_RHV_CARE_v1.6.2_12"
        WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%03d",100*WB) }')
    else
        LBL="RHV_CARE_v1.6.2_12"
        WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%02d",10*WB) }')
    fi
    VBFILENAME="gamma_V6_${LBL}_ATM${ATM}_zen${ZA}deg_${WOFFSET}wob_${NOISE}MHz*.zst"
elif [ ${SIMTYPE:0:4} == "CARE" ]; then
    VBFILENAME="*_${WOBBLE}wob_${NOISE}MHz*.zst"
fi
echo "VBF file name search string: $VBFILENAME"
VBFNAME=$(find ${SIMDIR} -name "$VBFILENAME" -not -name "*.log" -not -name "*.md5sum")

SUBMISSION_SCRIPT="$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh"
SUBC=$("$SUBMISSION_SCRIPT")
if [[ $SUBC == *"ERROR"* ]]; then
    echo "Error: reading submission type from $SUBMISSION_SCRIPT"
    exit 1
fi

#####################################
# Loop over all VBF files (one job per file)
for V in $VBFNAME; do
    echo "Preparing run scripts for ${V}"
    SIMDIR=$(dirname "$V")
    VBFFILE=$(basename ${V})

    # Update tmpdir depending on size of VBF file
    FF=$(ls -ls -Llh ${V} | awk '{print $1}' | sed 's/,/./g')
    # tmpdir requires a safety factor of 5. or higher (from unzipping VBF file)
    TMSF=$(echo "${FF%?}*5.0" | bc)
    if [[ ${SIMTYPE} = "CARE_RedHV" ]]; then
       # RedHV runs need more space during the analysis (otherwise quota is exceeded)
       TMSF=$(echo "${FF%?}*10.0" | bc)
    elif [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
       # GRISU files are bzipped, simulated without NSB, and need more space (factor of ~14)
       TMSF=$(echo "${FF%?}*25.0" | bc)
    fi
    TMUNI=$(echo "${FF: -1}")
    tmpdir_size=${TMSF%.*}$TMUNI
    echo "Setting TMPDIR_SIZE to $tmpdir_size"

    # Job submission scripts
    SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.evndisp_MC_sub.sh"
    FSCRIPT="${LOGDIR}/evn-$EPOCH-$SIMTYPE-$ZA-$WOBBLE-$NOISE-ATM$ATM-${RUNNUM}.sh"
    sed -e "s|DATADIR|$SIMDIR|" \
        -e "s|RUNNUMBER|$RUNNUM|" \
        -e "s|ZENITHANGLE|$ZA|" \
        -e "s|ATMOSPHERE|$ATM|" \
        -e "s|OUTPUTDIR|$OPDIR|" \
        -e "s|DECIMALWOBBLE|$WOBBLE|" \
        -e "s|INTEGERWOBBLE|$INT_WOBBLE|" \
        -e "s|NOISELEVEL|$NOISE|" \
        -e "s|ARRAYEPOCH|$EPOCH|" \
        -e "s|RECONSTRUCTIONRUNPARAMETERFILE|$ACUTS|" \
        -e "s|SIMULATIONTYPE|$SIMTYPE|" \
        -e "s|VBFFFILE|$VBFFILE|" \
        -e "s|VVERSION|$EDVERSION|" \
        -e "s|ADDITIONALOPTIONS|$EDOPTIONS|" \
        -e "s|NOISEFFILE|$NOISEFILE|"  $SUBSCRIPT > $FSCRIPT

    chmod u+x "$FSCRIPT"
    echo "Run script: $FSCRIPT"

    let "RUNNUM = ${RUNNUM} + 100"

    if [[ $SUBC == *"qsub"* ]]; then
        JOBID=$($SUBC "$FSCRIPT")
        echo "RUN $RUNNUM: JOBID $JOBID"
    elif [[ $SUBC == *"condor"* ]]; then
        "$(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh" "$FSCRIPT" "$h_vmem" "$default_tmpdir_size"
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT &> $(basename $FSCRIPT .sh).log" >> "$LOGDIR/runscripts.dat"
    fi
done
