#!/bin/bash
# analyse MC files with lookup tables
# and run effective area analysis

# qsub parameters
h_cpu=11:29:00; h_vmem=15000M; tmpdir_size=100G

if [[ $# -lt 10 ]]; then
# begin help message
echo "
IRF generation: analyze simulation evndisp files using mscw_energy (analyse all NSB and offset angles simulatenously)
                create partial effective area files from MC ROOT files

IRF.generate_mscw_effective_area_parts.sh <table file> <cuts file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT]

required parameters:

    <table file>            mscw_energy lookup table file
    
    <cuts file>             gamma/hadron cuts file (located in
                            \$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles)
                            (might be a list of cut files)

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

    [uuid]                  UUID used for submit directory

    [version]               Eventdisplay version (e.g., v490)

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# date used in run scripts / log file directories
DATE=`date +"%y%m%d"`

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
PARTICLE_TYPE="gamma"
[[ "${10}" ]] && ANALYSIS_TYPE=${10}  || ANALYSIS_TYPE=""
[[ "${11}" ]] && DISPBDT=${11} || DISPBDT=0
[[ "${12}" ]] && UUID=${12} || UUID=${DATE}-$(uuidgen)
[[ "${13}" ]] && EDVERSION=${13} || EDVERSION=$($EVNDISPSYS/bin/mscw_energy --version | tr -d .| sed -e 's/[a-Z]*$//')
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

# input directory containing evndisp products
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/"
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
echo "Input file directory: $INDIR"

# Output file directory
if [[ ! -z $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

LOGDIR="${VERITAS_IRFPRODUCTION_DIR}/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/submit-MSCWEFF-${UUID}"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.generate_mscw_effective_area_parts_sub"

WOFFS=${WOBBLE[*]}
NOISS=${NOISE[*]}
echo "Now processing zenith angle $ZA, wobble ${WOFFS}, noise level ${NOISS}"

# effective area output file
EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID${RECID}-Ze${ZA}deg"

# make run script
FSCRIPT="$LOGDIR/MSCWEFFAREA-ARRAY-$EPOCH-$ZA-$PARTICLE-${NOISE[0]}-CUTS-$DISPBDT-$DATE.MC_$(date +%s)"
rm -f "$FSCRIPT.sh"
sed -e "s|ZENITHANGLE|$ZA|" \
    -e "s|NOISELEVEL|$NOISS|" \
    -e "s|WOBBLEOFFSET|$WOFFS|" \
    -e "s|ARRAYEPOCH|$EPOCH|" \
    -e "s|RECONSTRUCTIONID|$RECID|" \
    -e "s|USEDISP|${DISPBDT}|" \
    -e "s|TABLEFILE|$TABFILE|" \
    -e "s|EFFFILE|$EFFAREAFILE|" \
    -e "s|GAMMACUTS|${CUTSFILE}|" \
    -e "s|ATMOS|${ATM}|" \
    -e "s|INPUTDIR|$INDIR|" \
    -e "s|OUTPUTDIR|$ODIR|" $SUBSCRIPT.sh > $FSCRIPT.sh

chmod u+x "$FSCRIPT.sh"
echo "Run script written to: $FSCRIPT"

exit

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
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs at once:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
    echo
elif [[ $SUBC == *sbatch* ]]; then
    $SUBC $FSCRIPT.sh
elif [[ $SUBC == *parallel* ]]; then
    echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
elif [[ "$SUBC" == *simple* ]]; then
    "$FSCRIPT.sh" | tee "$FSCRIPT.log"
fi
echo "LOG/SUBMIT DIR: ${LOGDIR}"

exit
