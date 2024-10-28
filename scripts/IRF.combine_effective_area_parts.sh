#!/bin/bash
# combine effective area files into one

# job requirements
h_cpu=11:29:00; h_vmem=12000M; tmpdir_size=20G
#
# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 5 ]; then
echo "
IRF generation: combine partial effective area files

IRF.combine_effective_area_parts.sh <cuts file> <epoch> <atmosphere> <Rec ID> <sim type> [name] [analysis type] [dispBDT]

required parameters:

    <cuts file>             gamma/hadron cuts file

    <epoch>                 array epoch (e.g., V4, V5, V6)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <sim type>              simulation type (e.g. GRISU-SW6, CARE_June1425)

optional parameters:

   [name]                   name added to the effective area output file
                            (default is today's date)

   [analysis type]          type of analysis (default="")

    [dispBDT]              use dispDBDT angular reconstruction
                           (default: 0; use: 1)


--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# date used in run scripts / log file directories
DATE=$(date +"%y%m%d")

# Parse command line arguments
CUTSFILE=$1
EPOCH=$2
ATMOS=$3
RECID=$4
SIMTYPE=$5
[[ "$6" ]] && EANAME=$6 || EANAME="${DATE}"
[[ "$7" ]] && ANALYSIS_TYPE=$7  || ANALYSIS_TYPE=""
[[ "$8" ]] && DISPBDT=$8 || DISPBDT=0
[[ "${9}" ]] && UUID=${9} || UUID=${DATE}-$(uuidgen)

# Generate EA base file name based on cuts file
CUTS_NAME=`basename $CUTSFILE`
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
CUTS_NAME=${CUTS_NAME%%.dat}

# input directory with effective areas
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    INDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATMOS}_gamma/EffectiveAreas_${CUTS_NAME}"
    if [[ $DISPBDT == "1" ]]; then
        INDIR="${INDIR}_DISP"
    fi
fi
if [[ ! -d $INDIR ]]; then
    echo "Error, could not locate input directory. Locations searched:"
    echo "$INDIR"
    exit 1
fi
INFILES="$INDIR/*ID${RECID}-*.root"
echo "Input file directory: $INDIR"
echo "Input files: $INFILES"

# Output file directory
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATMOS}_gamma/EffectiveAreas"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

# run scripts and output are written into this directory
LOGDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATMOS}_gamma/submit-COMBINEEFFAREAS-${UUID}/"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# telescope combinations
[[ $RECID == 0 ]] && T="1234"
[[ $RECID == 2 ]] && T="234"
[[ $RECID == 3 ]] && T="134"
[[ $RECID == 4 ]] && T="124"
[[ $RECID == 5 ]] && T="123"
[[ $RECID == 6 ]] && T="12"
[[ $RECID == 1 ]] && T="1234"
[[ $RECID == 7 ]] && T="234"
[[ $RECID == 8 ]] && T="134"
[[ $RECID == 9 ]] && T="124"
[[ $RECID == 10 ]] && T="123"

# loop over all files/cases
echo "Processing epoch $EPOCH, atmosphere ATM$ATMOS, RecID $RECID (telescope combination T${T})"

# output effective area name
METH="GEO"
if [[ ! -z $ANALYSIS_TYPE ]]; then
    METH=${ANALYSIS_TYPE}
fi
if [[ $DISPBDT == "1" ]]; then
    METH="${METH}-DISP"
fi
OFILE="effArea-${EDVERSION}-${EANAME}-$SIMTYPE-${CUTS_NAME}-${METH}-${EPOCH}-ATM${ATMOS}-T${T}"

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.effective_area_combine_sub"

# make run script
FSCRIPT="$LOGDIR/COMB-EFFAREA-${CUTS_NAME}-ATM${ATMOS}-${EPOCH}-ID${RECID}-${DISPBDT}-$(date +%s%N)"
rm -f $FSCRIPT.sh

sed -e "s|INPUTFILES|$INFILES|" \
    -e "s|OUTPUTFILE|$OFILE|"   \
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
