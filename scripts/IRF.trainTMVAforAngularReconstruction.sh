#!/bin/bash
# submit TMVA training for angular reconstruction

# qsub parameters
h_cpu=47:29:00; h_vmem=16000M; tmpdir_size=100G

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

    <atmosphere>            atmosphere model (61 = winter, 62 = summer)

    <zenith>                zenith angle of simulations [deg]

    <offset angle>          list of offset angle of simulations [deg]

    <NSB level>             list of NSB level of simulations [MHz]

    <Rec ID>                reconstruction ID
                            (see EVNDISP.reconstruction.runparameter)

    <sim type>              simulation type (e.g. GRISU, CARE_June1425)

optional parameters:

    [analysis type]         type of analysis (default="")

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

EPOCH="$1"
ATM="$2"
ZA="$3"
WOBBLE="$4"
NOISE="$5"
RECID="$6"
SIMTYPE="$7"
ANALYSIS_TYPE="${8:-}"
UUID="${9:-$(date +"%y%m%d")-$(uuidgen)}"

if [[ -z "$VERITAS_IRFPRODUCTION_DIR" ]]; then
    echo "Error: IRF production directory not found: $VERITAS_IRFPRODUCTION_DIR"
    exit 1
fi
# output and log directories
ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANALYSIS_TYPE}/$SIMTYPE/${EPOCH}_ATM${ATM}_gamma/TMVA_AngularReconstruction/ze${ZA}deg/"
LOGDIR="${VERITAS_USER_LOG_DIR}/${ANALYSIS_TYPE}/TMVAAngRes-${EPOCH}-ATM${ATM}-${UUID}"
mkdir -p "$ODIR"
chmod g+w "$ODIR"
mkdir -p "$LOGDIR"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"

# TMVA option file
TMVAOPTIONFILE="${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/TMVA.BDTDisp.runparameter"

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

SUBSCRIPT=$( dirname "$0" )"/helper_scripts/IRF.trainTMVAforAngularReconstruction_sub.sh"
for disp in BDTDispEnergy BDTDisp BDTDispError BDTDispSign
do
    for ((tel=1; tel<=4; tel++)); do

        echo "Processing $disp Telescope $tel Zenith = $ZA, Noise = $NOISE, Wobble = $WOBBLE"

        FSCRIPT="$LOGDIR/TA.${disp}.TEL${tel}ID${RECID}.${EPOCH}.ATM${ATM}.${ZA}.sh"
        sed -e "s|OUTPUTDIR|$ODIR|" \
            -e "s|EVNLIST|$EVNLIST|" \
            -e "s|VERSIONIRF|$EDVERSION|" \
            -e "s|BDTTYPE|$disp|" \
            -e "s|TMVAOPTIONFILE|$TMVAOPTIONFILE|" \
            -e "s|RRECID|$RECID|" \
            -e "s|TTYPE|$tel|" \
            -e "s|BDTFILE|$BDTFILE|" "$SUBSCRIPT" > "$FSCRIPT"

        chmod u+x "$FSCRIPT"
        echo "$FSCRIPT"

        # run locally or on cluster
        SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
        SUBC=`eval "echo \"$SUBC\""`
        if [[ $SUBC == *"ERROR"* ]]; then
            echo $SUBC
            exit
        fi
        if [[ $SUBC == *qsub* ]]; then
            JOBID=`$SUBC $FSCRIPT`
            echo "RUN $RUNNUM: JOBID $JOBID"
        elif [[ $SUBC == *condor* ]]; then
            $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT $h_vmem $tmpdir_size
            echo
            echo "-------------------------------------------------------------------------------"
            echo "Job submission using HTCondor - run the following script to submit jobs at once:"
            echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
            echo "-------------------------------------------------------------------------------"
            echo
        elif [[ $SUBC == *sbatch* ]]; then
                $SUBC $FSCRIPT
        elif [[ $SUBC == *parallel* ]]; then
            echo "$FSCRIPT &> $FSCRIPT.log" >> "$LOGDIR/runscripts.dat"
        fi
    done
done
