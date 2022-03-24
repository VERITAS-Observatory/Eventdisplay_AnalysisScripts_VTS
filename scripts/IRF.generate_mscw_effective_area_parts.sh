#!/bin/bash
# script to analyse MC files with lookup tables
# and run effective area analysis

# qsub parameters
h_cpu=11:29:00; h_vmem=15000M; tmpdir_size=100G

if [[ $# < 10 ]]; then
# begin help message
echo "
IRF generation: analyze simulation evndisp ROOT files using mscw_energy (analyse all NSB and offset angles simulatenously)
                create partial effective area files from MC ROOT files

IRF.generate_mscw_effective_area_parts.sh <table file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> <analysis type>

required parameters:

    <table file>            mscw_energy lookup table file
    
    <cuts file>             gamma/hadron cuts file (located in
                            \$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles)
                            (might be a list of cut files)

    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)

    <atmosphere>            atmosphere model (21 = winter, 22 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          list of offset angles of simulations [deg]

    <NSB level>             list of NSB level of simulations [MHz]
    
    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

                            Set to 0 for all telescopes, 1 to cut T1, etc.

    <sim type>              simulation type (e.g. GRISU-SW6, CARE_June1425)

    <analysis type>         type of analysis (default="")

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# EventDisplay version
IRFVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d .| sed -e 's/[a-Z]*$//'`

# Parse command line arguments
TABFILE=$1
TABFILE=${TABFILE%%.root}.root
CUTSFILE="$2"
EPOCH=$3
ATM=$4
ZA=$5
WOBBLE=$6
NOISE=$7
RECID=$8
SIMTYPE=$9
[[ "${10}" ]] && ANALYSIS_TYPE=${10}  || ANALYSIS_TYPE=""

# Particle names
PARTICLE=1
PARTICLE_NAMES=( [1]=gamma [2]=electron [14]=proton [402]=alpha )
PARTICLE_TYPE=${PARTICLE_NAMES[$PARTICLE]}

CUTS_NAME=`basename $CUTSFILE`
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
CUTS_NAME=${CUTS_NAME%%.dat}

# Check that table file exists
if [[ "$TABFILE" == `basename "$TABFILE"` ]]; then
    TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
fi
if [[ ! -f "$TABFILE" ]]; then
    echo "Error, table file not found, exiting..."
    echo "$TABFILE"
    exit 1
fi

_sizecallineraw=$(grep "* s " ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/ThroughputCorrection.runparameter | grep " ${EPOCH} ")
EPOCH_LABEL=$(echo "$_sizecallineraw" | awk '{print $3}')
# input directories containing evndisp products
INDIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    for W in ${WOBBLE}; do
       for N in ${NOISE}; do
          TDIR="${INDIR}/ze${ZA}deg_offset${W}deg_NSB${N}MHz"
          if [[ ! -d $TDIR ]]; then
              echo -e "Error, could not locate input directory. Locations searched:\n $TDIR"
              exit 1
          fi
          echo "Input file directory: $TDIR"
         done
   done
fi

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/MSCWEFFAREA.ANATABLES/$(date +%s%N)/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# Output file directory
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH_LABEL}_ATM${ATM}_${PARTICLE_TYPE}"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.generate_mscw_effective_area_parts_sub"

WOFFS=${WOBBLE[*]}
NOISS=${NOISE[*]}
echo "Now processing zenith angle $ZA, wobble ${WOFFS}, noise level ${NOISS}"

# effective area output file
EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID${RECID}-Ze${ZA}deg"

# make run script
FSCRIPT="$LOGDIR/MSCWEFFAREA-ARRAY-$EPOCH-$ZA-$PARTICLE-${NOISE[0]}-${CUTS_NAME}-$DATE.MC_$(date +%s)"
sed -e "s|INPUTDIR|$INDIR|" \
    -e "s|OUTPUTDIR|$ODIR|" \
    -e "s|TABLEFILE|$TABFILE|" \
    -e "s|EFFFILE|$EFFAREAFILE|" \
    -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISS|" \
    -e "s|WOBBLEOFFSET|$WOFFS|" \
    -e "s|GAMMACUTS|${CUTSFILE}|" \
    -e "s|RECONSTRUCTIONID|$RECID|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x "$FSCRIPT.sh"
echo "$FSCRIPT.sh"

# run locally or on cluster
SUBC=`$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh`
SUBC=`eval "echo \"$SUBC\""`
if [[ $SUBC == *"ERROR"* ]]; then
    echo "$SUBC"
    exit
fi
if [[ $SUBC == *qsub* ]]; then
    JOBID=`$SUBC $FSCRIPT.sh`
    echo "JOBID: $JOBID"
elif [[ $SUBC == *condor* ]]; then
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
    condor_submit $FSCRIPT.sh.condor
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi

exit
