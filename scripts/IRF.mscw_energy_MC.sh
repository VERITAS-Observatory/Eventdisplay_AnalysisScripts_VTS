#!/bin/bash
# script to analyse MC files with lookup tables

# qsub parameters
h_cpu=10:29:00; h_vmem=6000M; tmpdir_size=100G

if [[ $# -lt 8 ]]; then
# begin help message
echo "
IRF generation: analyze simulation evndisp ROOT files using mscw_energy 

IRF.mscw_energy_MC.sh <table file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT]

required parameters:

    <table file>            mscw_energy lookup table file
    
    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          offset angle of simulations [deg]

    <NSB level>             NSB level of simulations [MHz]

    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <sim type>              simulation type (e.g. GRISU-SW6, CARE_June1425)

optional parameters:

    [analysis type]         type of analysis (default="")
    
    [dispBDT]              use dispDBDT angular reconstruction
                           (default: 0; use: 1)
                            
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
EPOCH=$2
ATM=$3
ZA=$4
WOBBLE=$5
NOISE=$6
RECID=$7
SIMTYPE=$8
PARTICLE_TYPE="gamma"
[[ "$9" ]] && ANALYSIS_TYPE=$9 || ANALYSIS_TYPE=""
[[ "${10}" ]] && DISPBDT=${10} || DISPBDT=0
EVNIRFVERSION="v4N"

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

# input directory containing evndisp products
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz"
fi
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched:"
    echo "$INDIR"
    exit 1
fi
echo "Input file directory: $INDIR"

NROOTFILES=$( ls -l "$INDIR"/*.root.zst | wc -l )
echo "NROOTFILES $NROOTFILES"

# Output file directory
if [[ ! -z $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH_LABEL}_ATM${ATM}_${PARTICLE_TYPE}"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

# run scripts and output are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/MSCW.ANATABLES/${ANALYSIS_TYPE}/$(date +%s | cut -c -8)/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.mscw_energy_MC_sub"

echo "Processing Zenith = $ZA, Wobble = $WOBBLE, Noise = $NOISE (DISP: $DISPBDT)"

# make run script
FSCRIPT="$LOGDIR/MSCW-$EPOCH-$ATM-$ZA-$WOBBLE-$NOISE-${PARTICLE_TYPE}-$RECID-$DISPBDT"
rm -f "$FSCRIPT.sh"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISE|" \
    -e "s|WOBBLEOFFSET|$WOBBLE|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|ATMOS|$ATM|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|USEDISP|${DISPBDT}|" \
    -e "s|NFILES|$NROOTFILES|" \
    -e "s|TABLEFILE|$TABFILE|" \
    -e "s|INPUTDIR|$INDIR|" \
    -e "s|OUTPUTDIR|$ODIR|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x "$FSCRIPT.sh"
echo "Run script written to: $FSCRIPT"

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
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi

exit
