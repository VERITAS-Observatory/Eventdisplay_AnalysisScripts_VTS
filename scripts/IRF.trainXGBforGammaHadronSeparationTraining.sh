#!/bin/bash
# train XGB for gamma/hadron separation
#
# - training at wobble offsets 0.5 deg only

# shellcheck disable=SC2034  # SGE resource directives, read by job scheduler
h_cpu=21:59:59; h_vmem=16000M; tmpdir_size=24G; ncore=8
EDVERSION=$(cat "$VERITAS_EVNDISP_AUX_DIR"/IRFVERSION)

if [ $# -lt 6 ]; then
echo "
XGB (BDT) training for gamma/hadron separation

IRF.trainXGBforGammaHadronSeparationTraining.sh <background file directory> <run-parameter file> <output directory> <sim type> <epoch> <atmosphere> [uuid] [zenith angles] [NSB levels] [wobble offsets]

required parameters:

    <background file directory>     directory with background training (mscw) files

    <run-parameter file>            run-parameter file with basic options (incl. whole range of
	                            energy and zenith angle bins) and full path

    <output directory>              XGB files are written to this directory

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
    bash "$(dirname "$0")/helper_scripts/UTILITY.script_init.sh" || exit 1
fi

BDIR="$1"
RUNPAR="$2"
ODIR="$3"
SIMTYPE="$4"
EPOCH="$5"
ATM="$6"
RECID="0"
PARTICLE_TYPE="gamma"
UUID="${7:-$(date +"%y%m%d")-$(uuidgen)}"
TRAIN_ZENITH_ANGLES="${8:-}"
TRAIN_NSB_LEVELS="${9:-}"
TRAIN_WOBBLE_OFFSETS="${10:-}"

echo "Background file directory: $BDIR"
echo "Run parameters: $RUNPAR"
echo "Simulation type: $SIMTYPE"

# Training parameter space is defined by IRF.production.sh.
if [[ ${SIMTYPE} == *"RedHV"* ]] && [[ -z "$TRAIN_NSB_LEVELS" ]]; then
    echo "Training NSB levels not provided for RedHV training"
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
if [[ "$RUNPAR" == $(basename "$RUNPAR") ]]; then
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNPAR"
fi
if [[ ! -f "$RUNPAR" ]]; then
    echo "Error, XGB run parameter file $RUNPAR not found, exiting..."
    exit 1
fi

LOGDIR="$ODIR/XGB.ANADATA.${UUID}"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"
mkdir -p "$LOGDIR"
mkdir -p "$ODIR"

#####################################
# energy / zenith bins
NENE=$(jq '.energy_bins_log10_tev | length' "$RUNPAR")
NEZE=$(jq '.zenith_bins_deg | length' "$RUNPAR")
echo "Number of energy / zenith bins: $NENE $NEZE"

#####################################
# zenith angle / NSB / wobble bins of MC simulation files
read -r -a ZENITH_ANGLES <<< "$TRAIN_ZENITH_ANGLES"
read -r -a NOISE_VALUES <<< "$TRAIN_NSB_LEVELS"
read -r -a WOBBLE_OFFSETS <<< "$TRAIN_WOBBLE_OFFSETS"
if [[ ${#ZENITH_ANGLES[@]} -eq 0 ]] || [[ ${#NOISE_VALUES[@]} -eq 0 ]] || [[ ${#WOBBLE_OFFSETS[@]} -eq 0 ]]; then
    mapfile -t ZENITH_ANGLES < <(jq -r '.input_zenith_angles[]' "$RUNPAR")
    mapfile -t NOISE_VALUES < <(jq -r '.input_noise_values[]' "$RUNPAR")
    WOBBLE_OFFSETS=( 0.5 )
fi
if [[ ${#ZENITH_ANGLES[@]} -eq 0 ]] || [[ ${#NOISE_VALUES[@]} -eq 0 ]] || [[ ${#WOBBLE_OFFSETS[@]} -eq 0 ]]; then
    echo "Error: no valid training parameter space found"
    exit 1
fi

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
SUBSCRIPT="$(dirname "$0")/helper_scripts/IRF.trainXGBforGammaHadronSeparation_sub.sh"
HELPER_SCRIPTS_DIR="$(cd "$(dirname "$0")/helper_scripts" && pwd)"

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
            for wobble in "${WOBBLE_OFFSETS[@]}"; do
                f="${SDIR}/${z}deg_${wobble}wob_NOISE${n}.mscw.root"
                [[ -f "$f" ]] && echo "$f" >> "$SIGNALLIST"
            done
        done
    done
fi

BCKLIST="${ODIR}/bck_files.list"
echo "Background file list: $BCKLIST"
rm -f "${BCKLIST}"
touch "${BCKLIST}"
tmpfile=$(mktemp)
for ((i=0; i<NEZE; i++)); do
  if [[ ! -d "${BDIR}/Ze_${i}" ]]; then
      echo "Error, directory with background files ${BDIR}/Ze_${i} not found, exiting..."
      exit 1
  fi
  find "${BDIR}"/Ze_${i} -name "*.root" | shuf -n 1000 >> "${tmpfile}"
done
shuf "$tmpfile" > "${BCKLIST}"
rm "$tmpfile"

###############################################################
# loop over energy bins and submit a job for each bin
for (( i=0; i < NENE; i++ )); do
    echo "Energy Bin: $i"

    FSCRIPT=$LOGDIR/XGBGAMMA"_$EPOCH""_ENERGY$i.sh"
    sed -e "s|MSCWSIGNAL|$SIGNALLIST|"  \
        -e "s|MSCWBCK|$BCKLIST|" \
        -e "s|MODELPARA|$RUNPAR|" \
        -e "s|ENERGYBIN|$i|" \
	-e "s|NCORES|$ncore|" \
        -e "s|HHELPER_SCRIPTS_DIR|$HELPER_SCRIPTS_DIR|" \
        -e "s|EENV_SNAPSHOT_DIR|$LOGDIR|" \
        -e "s|OUTPUTDIR|${ODIR}|" "$SUBSCRIPT" > "$FSCRIPT"

    chmod u+x "$FSCRIPT"
    echo "$FSCRIPT"

    # run locally or on cluster
    SUBC=$("$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh")
    SUBC=$(eval "echo \"$SUBC\"")
    if [[ $SUBC == *"ERROR"* ]]; then
        echo "$SUBC"
        exit
    fi
    "$(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh" "$FSCRIPT" "$h_vmem" "$tmpdir_size"
    echo
    echo "-------------------------------------------------------------------------------"
    echo "Job submission using HTCondor - run the following script to submit jobs at once:"
    echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
    echo "-------------------------------------------------------------------------------"
    echo
done
