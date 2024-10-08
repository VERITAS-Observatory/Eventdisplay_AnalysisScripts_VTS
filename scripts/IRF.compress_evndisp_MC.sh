#!/bin/bash
# submit cleanup job after running evndisp
#

# qsub parameters
h_cpu=0:29:00; h_vmem=4000M; tmpdir_size=20G

if [ $# -lt 7 ]; then
# begin help message
echo "
IRF generation: compress evndisp output and move log files into final provduct

IRF.compress_evndisp_MC.sh <sim directory> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <sim type> [analysis type]  [uuid]

required parameters:

    <sim directory>         directory containing simulation VBF files

    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)

    <atmosphere>            atmosphere model (21 = winter, 22 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]

    <sim type>              file simulation type (e.g. GRISU-SW6, CARE_June1425)


optional parameters:

    [analysis type]         type of analysis (default="")

    [uuid]                  UUID used for submit directory

Note: zenith angles, wobble offsets, and noise values are hard-coded into script

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/evndisp --version | tr -d .`
# directory for run scripts
DATE=`date +"%y%m%d"`

# Parse command line arguments
SIMDIR=$1
EPOCH=$2
ATM=$3
ZA=$4
WOBBLE=$5
NOISE=$6
SIMTYPE=$7
PARTICLE=1
[[ "${8}" ]] && ANALYSIS_TYPE=${8} || ANALYSIS_TYPE=""
[[ "${9}" ]] && UUID=${9} || UUID=${DATE}-$(uuidgen)

# Particle names
PARTICLE_NAMES=( [1]=gamma [2]=electron [14]=proton [402]=alpha )
PARTICLE_TYPE=${PARTICLE_NAMES[$PARTICLE]}

# input/output directory for evndisp products
if [[ ! -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    IDIR="$VERITAS_IRFPRODUCTION_DIR/${EDVERSION}/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
fi
# input dir
IPDIR=${IDIR}"/ze"$ZA"deg_offset"$WOBBLE"deg_NSB"$NOISE"MHz"
OPDIR=${IPDIR}
mkdir -p "$OPDIR"
chmod -R g+w "$OPDIR"
echo -e "Output files will be written to:\n $OPDIR"
LOGDIR="${VERITAS_IRFPRODUCTION_DIR}/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/submit-${UUID}/"
mkdir -p "$LOGDIR"
echo -e "input files will be read from:\n $IPDIR"

# Analysis options
EDOPTIONS=""
if [[ ${ANALYSIS_TYPE} == *"SQ2"* ]]; then
   EDOPTIONS="-imagesquared"
fi

# Create a unique set of run numbers
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="946500"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="956500"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="966500"
elif [ ${SIMTYPE:0:4} = "CARE" ]; then
    [[ ${EPOCH:0:2} == "V4" ]] && RUNNUM="941200"
    [[ ${EPOCH:0:2} == "V5" ]] && RUNNUM="951200"
    [[ ${EPOCH:0:2} == "V6" ]] && RUNNUM="961200"
fi

INT_WOBBLE=`echo "$WOBBLE*100" | bc | awk -F '.' '{print $1}'`
if [[ ${#INT_WOBBLE} -lt 2 ]]; then
   INT_WOBBLE="000"
elif [[ ${#INT_WOBBLE} -lt 3 ]]; then
   INT_WOBBLE="0$INT_WOBBLE"
fi

################################################################
# Find simulation file depending on the type of simulations
# VBFNAME - name of VBF file
# NOISEFILE - noise library (in grisu format)
VBFNAME="NO_VBFNAME"
NOISEFILE="NO_NOISEFILE"

#######################################################
# GRISU simulations
if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
    if [[ -z $VERITAS_EVNDISP_AUX_DIR ]]; then
        VERITAS_EVNDISP_AUX_DIR=$VERITAS_EVNDISP_AUX_DIR
    fi
    # Input files (observe that these might need some adjustments)
    if [[ ${EPOCH:0:2} == "V4" ]]; then
        if [[ $ATM == "21" ]]; then
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "Oct2012_oa_ATM21_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        else
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V4_Oct2012_SummerV4ForProcessing_20130611_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        fi
        NOISEFILE="$VERITAS_EVNDISP_AUX_DIR/NOISE/NOISE$NOISE.grisu"
    elif [[ ${EPOCH:0:2} == "V5" ]]; then
        VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V5_Oct2012_newArrayConfig_20121027_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        NOISEFILE="$VERITAS_EVNDISP_AUX_DIR/NOISE/NOISE$NOISE.grisu"
    elif [[ ${EPOCH:0:2} == "V6" ]]; then
        if [[ $ATM == "21-redHV" ]]; then
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_Upgrade_ReducedHV_20121211_v420_ATM21_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        elif [[ $ATM == "21-UV" ]]; then
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_Upgrade_UVfilters_20121211_v420_ATM21_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        elif [[ $ATM == "21-SNR" ]]; then
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_201304_SN2013ak_v420_ATM21_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        else
            VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_Upgrade_20121127_v420_ATM${ATM}_${ZA}deg_${INT_WOBBLE}*" -not -name "*.log" -not -name "*.md5sum")
        fi
        NOISEFILE="$VERITAS_EVNDISP_AUX_DIR/NOISE/NOISE${NOISE}_20120827_v420.grisu"
    fi
#######################################################
elif [ ${SIMTYPE} == "CARE_UV_June1409" ]; then
    # example gamma_00deg_750m_0.5wob_180mhz_up_ATM21_part0.cvbf.bz2
    WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%03d",100*WB) }')
    VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_${ZA}deg_750m_${WOBBLE}wob_${NOISE}mhz_up_ATM${ATM}_part0.cvbf.bz2")
#######################################################
elif [ ${SIMTYPE} == "CARE_UV_2212" ]; then
    # example gamma_V6_CARE_uvf_Atmosphere61_zen20deg_0.25wob_120MHz.vbf.zst
    LBL="CARE_uvf"
    VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_${LBL}_Atmosphere${ATM}_zen${ZA}deg_${WOBBLE}wob_${NOISE}MHz*.zst" -not -name "*.log" -not -name "*.md5sum")
    echo "gamma_V6_${LBL}_Atmosphere${ATM}_zen${ZA}deg_${WOFFSET}wob_${NOISE}MHz"
#######################################################
elif [ ${SIMTYPE:0:10} == "CARE_RedHV" ]; then
    # example gamma_V6_PMTUpgrade_RHV_CARE_v1.6.2_12_ATM61_zen40deg_050wob_150MHz.cvbf.zst
    if [[ ${ATM} == 61 ]]; then
        LBL="PMTUpgrade_RHV_CARE_v1.6.2_12"
        WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%03d",100*WB) }')
    else
        LBL="RHV_CARE_v1.6.2_12"
        WOFFSET=$(awk -v WB=$WOBBLE 'BEGIN { printf("%02d",10*WB) }')
    fi
    VBFNAME=$(find ${SIMDIR}/ -maxdepth 1 -name "gamma_V6_${LBL}_ATM${ATM}_zen${ZA}deg_${WOFFSET}wob_${NOISE}MHz*.zst" -not -name "*.log" -not -name "*.md5sum")
#######################################################
elif [ ${SIMTYPE} == "CARE_June2020" ]; then
    VBFNAME=$(find ${SIMDIR} -name "*_${WOBBLE}wob_${NOISE}MHz*.zst" -not -name "*.log" -not -name "*.md5sum")
    echo _${WOFFSET}wob_${NOISE}MHz
    echo $SIMDIR/Zd${ZA}/merged/Data/
#######################################################
elif [ ${SIMTYPE:0:4} == "CARE" ]; then
    # input files (observe that these might need some adjustments)
    if [[ $PARTICLE == "1" ]]; then
       VBFNAME=$(find ${SIMDIR}/ -name "gamma_${ZA}deg*${WOBBLE}wob_${NOISE}mhz*ATM${ATM}*.zst" -not -name "*.log" -not -name "*.md5sum")
    elif [[ $PARTICLE == "2" ]]; then
       VBFNAME=$(find ${SIMDIR} -name "electron_${ZA}deg*${WOBBLE}wob_${NOISE}mhz*ATM${ATM}*.zst" -not -name "*.log" -not -name "*.md5sum")
    elif [[ $PARTICLE == "14" ]]; then
       VBFNAME=$(find ${SIMDIR} -name "proton_${ZA}deg*${WOBBLE}wob_${NOISE}mhz*ATM${ATM}*.zst" -not -name "*.log" -not -name "*.md5sum")
    fi
fi
#######################################################

#####################################
# Loop over all VBFFiles
for V in ${VBFNAME}
do
    echo "Processing ${V}"
    SIMDIR=$(dirname ${V})

    # size of VBF file
    FF=$(ls -ls -Llh ${V} | awk '{print $1}' | sed 's/,/./g')
    V=$(basename ${V})
    echo "SIMDIR: $SIMDIR"
    echo "VBFILE: ${V} $FF"
    echo "NOISEFILE: ${NOISEFILE}"
    # tmpdir requires a safety factor of 5. or higher (from unzipping VBF file)
    TMSF=$(echo "${FF%?}*5.0" | bc)
    if [[ ${SIMTYPE} = "CARE_RedHV" ]]; then
       # RedHV runs need more space during the analysis (otherwise quota is exceeded)
       TMSF=$(echo "${FF%?}*10.0" | bc)
    elif [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
       # GRISU files are bzipped and need more space (factor of ~14)
       TMSF=$(echo "${FF%?}*25.0" | bc)
    fi

    TMUNI=$(echo "${FF: -1}")
    tmpdir_size=${TMSF%.*}$TMUNI
    echo "Setting TMPDIR_SIZE to $tmpdir_size"

    # Job submission script
    SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.compress_evndisp_MC_sub"

    # make run script
    FSCRIPT="$LOGDIR/comp-$EPOCH-$SIMTYPE-$ZA-$WOBBLE-$NOISE-ATM$ATM-${RUNNUM}"
    sed -e "s|RUNNUMBER|$RUNNUM|" \
        -e "s|OUTPUTDIR|$OPDIR|" \
        -e "s|INPUTDIR|$IPDIR|" $SUBSCRIPT.sh > $FSCRIPT.sh

    chmod u+x $FSCRIPT.sh
    echo $FSCRIPT.sh

    let "RUNNUM = ${RUNNUM} + 100"

    # run locally or on cluster
    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    echo "$SUBC"
    if [[ $SUBC == *qsub* ]]; then
        JOBID=`$SUBC $FSCRIPT.sh`
        echo "RUN $RUNNUM: JOBID $JOBID"
    elif [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs at once:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
    fi
done
echo "LOG/SUBMIT DIR: ${LOGDIR}"

exit
