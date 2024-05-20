#!/bin/bash
# submit TMVA training for angular reconstruction

# qsub parameters
h_cpu=47:29:00; h_vmem=24000M; tmpdir_size=100G

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)
EVNIRFVERSION="v4N"

if [ $# -lt 7 ]; then
echo "
TMVA (BDT) training for angular resolution from MC ROOT files for different zenith angle bins
 (simulations that have been processed by evndisp_MC)

IRF.trainTMVAforAngularReconstruction.sh <epoch> <atmosphere> <zenith> <offset angle> <NSB level> <Rec ID> <sim type> [analysis type]

required parameters:

    <epoch>                 array epoch (e.g., V4, V5, V6)
                            V4: array before T1 move (before Fall 2009)
                            V5: array after T1 move (Fall 2009 - Fall 2012)
                            V6: array after camera update (after Fall 2012)

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          list of offset angle of simulations [deg]

    <NSB level>             list of NSB level of simulations [MHz]

    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <sim type>              simulation type (e.g. GRISU, CARE)

optional parameters:

    [analysis type]         type of analysis (default="")

    [uuid]                  UUID used for submit directory

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# date used in run scripts / log file directories
DATE=`date +"%y%m%d"`

# Parse command line arguments
EPOCH=$1
ATM=$2
ZA=$3
WOBBLE=$4
NOISE=$5
RECID=$6
SIMTYPE=$7
[[ "$8" ]] && ANALYSIS_TYPE=$8  || ANALYSIS_TYPE=""
[[ "${9}" ]] && UUID=${9} || UUID=${DATE}-$(uuidgen)

_sizecallineraw=$(grep "* s " ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/ThroughputCorrection.runparameter | grep " ${EPOCH} ")
EPOCH_LABEL=$(echo "$_sizecallineraw" | awk '{print $3}')

# Output file directory
TMVADIR="TMVA_AngularReconstruction"
if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH_LABEL}_ATM${ATM}_gamma/${TMVADIR}/ze${ZA}deg_loss02/"
fi
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"
chmod g+w "$ODIR"

# run scripts and output are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="${VERITAS_USER_LOG_DIR}/$DATE/${ANALYSIS_TYPE}/TMVAAngRes-${EPOCH}-ATM${ATM}-${UUID}"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# training file name
BDTFILE="mvaAngRes_${ZA}deg"

# prepare list of input files
EVNLIST=$ODIR/${BDTFILE}.list
rm -f ${EVNLIST}
touch ${EVNLIST}

check_evndisp_directory()
{
    # input directory containing evndisp products
    if [[ -n "$VERITAS_IRFPRODUCTION_DIR" ]]; then
        INDIR="$VERITAS_IRFPRODUCTION_DIR/${EVNIRFVERSION}/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/ze${ZA}deg_offset${1}deg_NSB${2}MHz"
    fi
    if [[ ! -d $INDIR ]]; then
        echo "Error, could not locate input directory. Locations searched:"
        echo "$INDIR"
        exit 1
    fi
    echo $INDIR
}

for W in ${WOBBLE}
do
    for N in ${NOISE}
    do
        check_evndisp_directory $W $N
        # choose a random file from all files
        ls -1 $INDIR/*[0-9].root.zst | sort -R | head -n 1 >> ${EVNLIST}
    done
done
echo "FILE LIST: ${EVNLIST}"

for disp in BDTDispEnergy BDTDisp BDTDispError BDTDispSign
do
    # Job submission script
    SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.trainTMVAforAngularReconstruction_sub"

    echo "Processing $disp Zenith = $ZA, Noise = $NOISE, Wobble = $WOBBLE"

    # make run script
    FSCRIPT="$LOGDIR/TA.${disp}.ID${RECID}.${EPOCH}.ATM${ATM}.${ZA}"
    sed -e "s|OUTPUTDIR|$ODIR|" \
        -e "s|EVNLIST|$EVNLIST|" \
        -e "s|VVERSION|$EDVERSION|" \
        -e "s|BDTTYPE|$disp|" \
        -e "s|BDTFILE|$BDTFILE|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"

    chmod u+x "$FSCRIPT.sh"
    echo "$FSCRIPT.sh"

    # run locally or on cluster
    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    if [[ $SUBC == *"ERROR"* ]]; then
        echo $SUBC
        exit
    fi
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
    elif [[ $SUBC == *sbatch* ]]; then
            $SUBC $FSCRIPT.sh
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
    fi
done
