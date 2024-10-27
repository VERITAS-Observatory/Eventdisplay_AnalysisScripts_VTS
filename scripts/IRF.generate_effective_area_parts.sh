#!/bin/bash
# calculate effective areas for a given point in the parameter space
# (output need to be combined afterwards)

# qsub parameters
h_cpu=13:29:00; h_vmem=8000M; tmpdir_size=20G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 8 ]; then
echo "
IRF generation: create partial effective area files from MC ROOT files
 (simulations that have been processed by both evndisp_MC and mscw_energy_MC)

IRF.generate_effective_area_parts.sh <cuts file> <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type] [dispBDT] [uuid]

required parameters:

    <cuts file>             gamma/hadron cuts file (located in
                             \$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles)
                            (might be a list of cut files)

    <epoch>                 array epoch (e.g., V4, V5, V6)

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

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ -z "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# Parse command line arguments
CUTSFILE="$1"
EPOCH=$2
ATM=$3
ZA=$4
WOBBLE=$5
NOISE=$6
RECID=$7
SIMTYPE=$8
[[ "$9" ]] && ANALYSIS_TYPE=$9 || ANALYSIS_TYPE=""
[[ "${10}" ]] && DISPBDT=${10} || DISPBDT=0
[[ "${11}" ]] && UUID=${11} || UUID=$(date +"%y%m%d")-$(uuidgen)

CUTS_NAME=`basename $CUTSFILE`
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
CUTS_NAME=${CUTS_NAME%%.dat}

# input directory containing mscw_energy_MC products
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/MSCW_RECID${RECID}"
    if [[ ${DISPBDT} == "1" ]]; then
        INDIR=${INDIR}_DISP
    fi
fi
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched: $INDIR"
    exit 1
fi
echo "Input file directory: $INDIR"

# Output file directory
if [[ -n $VERITAS_IRFPRODUCTION_DIR ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma"
fi
echo -e "Output files will be written to:\n $ODIR"
[[ ! -d "$ODIR" ]] && mkdir -p "$ODIR" && chmod g+w "$ODIR"

LOGDIR="${VERITAS_IRFPRODUCTION_DIR}/$EDVERSION/${ANALYSIS_TYPE}/${SIMTYPE}/${EPOCH}_ATM${ATM}_gamma/submit-EFFAREA-RECID${RECID}-${UUID}"
echo -e "Log files will be written to:\n $LOGDIR"
[[ ! -d "$LOGDIR" ]] && mkdir -p "$LOGDIR"

#################################
# template string containing the name of processed simulation root file
MCFILE="${INDIR}/${ZA}deg_${WOBBLE}wob_NOISE${NOISE}.mscw.root"

# effective area output file
EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID${RECID}-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.effective_area_parallel_sub"

echo "Processing Zenith = $ZA, Noise = $NOISE, Wobble = $WOBBLE"

echo "CUTSFILE: $CUTSFILE"
echo "ODIR: $ODIR"
echo "MC DATAFILE $MCFILE"
echo "EFFFILE $EFFAREAFILE"
# make run script
FSCRIPT="$LOGDIR/EA.ID${RECID}.${ZA}.${WOBBLE}.${NOISE}.${CUTS_NAME}"
sed -e "s|OUTPUTDIR|$ODIR|" \
    -e "s|EFFFILE|$EFFAREAFILE|" \
    -e "s|USEDISP|${DISPBDT}|" \
    -e "s|DATAFILE|$MCFILE|" \
    -e "s|GAMMACUTS|${CUTSFILE}|" $SUBSCRIPT.sh > $FSCRIPT.sh

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
