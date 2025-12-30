#!/bin/bash
# train XGB for gamma/hadron separation
#
# note the large amount of hardwired parameters in this scripts:
# - zenith angles to be trained
# - training at wobble offsets 0.5 deg only
# - fixed of NSB levels (adapted to stdHV settings)
#

# qsub parameters
h_cpu=11:59:59; h_vmem=8000M; tmpdir_size=24G
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 6 ]; then
echo "
XGB (BDT) training for gamma/hadron separation

IRF.trainXGBforGammaHadronSeparation.sh <background file directory> <run-parameter file> <output directory> <sim type> <epoch> <atmosphere>

required parameters:

    <background file directory>     directory with background training (mscw) files

    <run-parameter file>            run-parameter file with basic options (incl. whole range of
	                                energy and zenith angle bins) and full path

    <output directory>              BDT files are written to this directory

    <sim type>                      simulation type
                                    (e.g. GRISU, CARE_June2020, CARE_RedHV, CARE_UV)

    <epoch>                         array epoch e.g. V4, V5,
                                    V6 epochs: e.g., \"V6_2012_2013a V6_2012_2013b\"

    <atmosphere>                    atmosphere model (61 = winter, 62 = summer)

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ -z "$EVNDISP_APPTAINER" ]; then
    bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

BDIR="$1"
RUNPAR="$2"
ODIR="$3"
SIMTYPE="$4"
EPOCH="$5"
ATM="$6"
RECID="0"
PARTICLE_TYPE="gamma"
UUID="${7:-$(date +"%y%m%d")-$(uuidgen)}"

echo "Background file directory: $BDIR"
echo "Run parameters: $RUNPAR"
echo "Simulation type: $SIMTYPE"

# Fixed list of NSB levels; redHV needs attention
if [[ ${SIMTYPE} == *"RedHV"* ]]; then
    echo "Fixed NSB levels not suitable for RedHV training"
    exit 1
fi

DISPBDT=""
ANATYPE="AP"
if [[ ! -z $VERITAS_ANALYSIS_TYPE ]]; then
    ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
    if [[ ${VERITAS_ANALYSIS_TYPE} == *"DISP"* ]]; then
        DISPBDT="_DISP"
    fi
fi

# Check that background file directory exists
if [[ ! -d "$BDIR" ]]; then
    echo "Error, directory with background files $BDIR not found, exiting..."
    exit 1
fi

# Check that XGB run parameter file exists
if [[ "$RUNPAR" == `basename $RUNPAR` ]]; then
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNPAR"
fi
if [[ ! -f "$RUNPAR" ]]; then
    echo "Error, XGB run parameter file $RUNPAR not found, exiting..."
    exit 1
fi

LOGDIR="$ODIR/XGB.ANADATA.${UUID}"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"
mkdir -p $LOGDIR
mkdir -p $ODIR

#####################################
# energy bins
NENE=$(jq '.energy_bins_log10_tev | length' "$RUNPAR")
RUNPAR_CONTENT=$(cat "$RUNPAR")
echo "Number of energy bins: $NENE"

#####################################
# zenith angle bins of MC simulation files
ZENITH_ANGLES=( 20 30 35 40 45 50 55 60 65)
NOISE_VALUES=(100 160 200 250 350 450)

####################################
# Run prefix
get_run_prefix()
{
    RUNN="${1%%.*}"

    if [[ ${RUNN} -lt 100000 ]]; then
        echo "${RUNN:0:1}"
    else
        echo "${RUNN:0:2}"
    fi
}

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.trainXGBforGammaHadronSeparation_sub.sh"

SIGNALLIST="${ODIR}/signal_files.list"
rm -f "${SIGNALLIST}"
touch "${SIGNALLIST}"
SDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/$ANATYPE/$SIMTYPE/${EPOCH}_ATM${ATM}_${PARTICLE_TYPE}/MSCW_RECID${RECID}${DISPBDT}"
echo "Signal input directory: $SDIR"
echo "Signal file list: $SIGNALLIST"
if [[ ! -d $SDIR ]]; then
    echo -e "Error, could not locate directory of simulation files (input). Locations searched:\n $SDIR"
    exit 1
fi
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
    echo "NOT IMPLEMENTED YET"
    exit
else
    for z in "${ZENITH_ANGLES[@]}"; do
        for n in "${NOISE_VALUES[@]}"; do
            for f in "$SDIR"/"${z}deg_0.5wob_NOISE${n}.mscw.root"; do
                [[ -f "$f" ]] && echo "$f" >> "$SIGNALLIST"
            done
        done
    done
fi

BCKLIST="${ODIR}/bck_files.list"
echo "Background file list: $BCKLIST"
rm -f "${BCKLIST}"
touch "${BCKLIST}"
for ((i=0; i<=2; i++)); do
  if [[ ! -d "${BDIR}/Ze_${i}" ]]; then
      echo "Error, directory with background files ${BDIR}/Ze_${i} not found, exiting..."
      exit 1
  fi
  find ${BDIR}/Ze_${i} -name "*.root" -printf "%f\n" | sort -R | head -n 100 >> "${BCKLIST}"
done

###############################################################
# loop over all energy bins and submit a job for each bin
for (( i=0; i < $NENE; i++ ))
do
    echo "Energy Bin: $i"

    # TODO ntel 4 fixed
    FSCRIPT=$LOGDIR/XGBGAMMA"_$EPOCH""_ENERGY$i.sh"
    sed -e "s|MSCWSIGNAL|$SIGNALLIST|"  \
        -e "s|MSCWBCK|$BCKLIST|" \
        -e "s|MODELPARA|$RUNPAR|" \
        -e "s|ENERGYBIN|$i|" \
        -e "s|TTYPE|4|" \
        -e "s|OUTPUTDIR|${ODIR}|" $SUBSCRIPT > $FSCRIPT

    chmod u+x $FSCRIPT
    echo $FSCRIPT

    # run locally or on cluster
    SUBC=$($(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh)
    SUBC=$(eval "echo \"$SUBC\"")
    if [[ $SUBC == *"ERROR"* ]]; then
        echo $SUBC
        exit
    fi
    $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT $h_vmem $tmpdir_size
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs at once:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
    echo
done
