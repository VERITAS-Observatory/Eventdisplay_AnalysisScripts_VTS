#!/bin/bash
# shellcheck disable=SC2178,SC2128,SC2068
# IRF production script (VERITAS)

# EventDisplay version
EDVERSION=$(cat "$VERITAS_EVNDISP_AUX_DIR"/IRFVERSION)

if [ $# -lt 2 ]; then
echo "
IRF generation: produce a full set of instrument response functions (IRFs)

IRF.production.sh <sim type> <IRF type> [epoch] [atmosphere] [Rec ID] [cuts list file] [sim directory]

required parameters:

    <sim type>              simulation type
                            Main types: GRISU, CARE_24_20, CARE_RedHV_Feb2024, CARE_UV_2212
                            CARE_RedHV_Feb2024, CARE_202404, CARE_24_20)
                            V6 basic types: CARE_202404, CARE_RedHV_Feb2024
                            Other types: CARE_June2020, CARE_RedHV, CARE_UV

    <IRF type>              type of instrument response function to produce.
                            EVNDISP,
                            MAKETABLES, COMBINETABLES,
                            TRAINMVANGRES,
                            ANALYSETABLES, ANALYSETABLESXGBTRAIN
                            TRAINXGBANGRES, ANAXGBANGRES,
                            TRAINXGBGH, ANAXGBGH,
                            PRESELECTEFFECTIVEAREAS, COMBINEPRESELECTEFFECTIVEAREAS,
                            TRAINTMVA, OPTIMIZETMVA,
                            ANATABLESEFFAREAS,
                            EFFECTIVEAREAS, COMBINEEFFECTIVEAREAS,
                            (EVNDISPCOMPRESS, MVAEVNDISP)

optional parameters:

    [epoch]                 array epoch(s) (e.g., V4, V5, V6)
                            (default: \"V4 V5 V6\")
                            (V6 epochs: e.g., \"V6_2012_2013a V6_2012_2013b V6_2013_2014a V6_2013_2014b
                             V6_2014_2015 V6_2015_2016 V6_2016_2017 V6_2017_2018 V6_2018_2019 V6_2019_2020
                             V6_2019_2020w V6_2020_2020s V6_2020_2021w V6_2021_2021s V6_2021_2022w
                             V6_2022_2022s V6_2022_2023w V6_2023_2023s V6_2023_2024w V6_2024_2024s
                             V6_2024_2025w V6_2025_2025s V6_2025_2026w \")

    [atmosphere]            atmosphere model(s) (21/61 = winter, 22/62 = summer)
                            (default: \"61 62\")

    [Rec ID]                reconstruction ID(s) (default: \"0 2 3 4 5\")
                            (see EVNDISP.reconstruction.runparameter)

    [cuts list file]        file containing one gamma/hadron cuts file per line
                            required for PRESELECTEFFECTIVEAREAS, EFFECTIVEAREAS, COMBINEPRESELECTEFFECTIVEAREAS,
                            COMBINEEFFECTIVEAREAS, ANATABLESEFFAREAS
                            Typically found in \"$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS*\"
                            Full path.

    [sim directory]         directory containing simulation VBF files

    example:     ./IRF.production.sh CARE_June2020 ANALYSETABLES V6 61 0

--------------------------------------------------------------------------------
"
exit
fi

# We need to be in the IRF.production.sh directory so that subscripts are called
# (we call them ./).
olddir=$(pwd)
cd "$(dirname "$0")" || exit

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh" || exit 1
fi

# Parse command line arguments
SIMTYPE="$1"
IRFTYPE="$2"
[[ "$3" ]] && EPOCH="$3" || EPOCH="V6 V5 V4"
[[ "$4" ]] && ATMOS="$4" || ATMOS="61 62"
[[ "$5" ]] && RECID="$5" || RECID="0"
[[ "$6" ]] && CUTSLISTFILE="$6" || CUTSLISTFILE=""
[[ "$7" ]] && SIMDIR="$7" || SIMDIR=""

# uuid for this job batch
DATE=$(date +"%y%m%d")
UUID=${DATE}-$(uuidgen)

# version string for aux files
AUX="auxv01"
# Analysis Type
ANATYPE="AP"
DISPBDT=0
if [[ ! -z  $VERITAS_ANALYSIS_TYPE ]]; then
   ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
   if [[ ${VERITAS_ANALYSIS_TYPE} == *"DISP"* ]]; then
       DISPBDT="1"
   fi
fi

# run parameter file for evndisp analysis
ACUTS="EVNDISP.reconstruction.runparameter.AP.v4x"
if [[ $ANATYPE = "NN"* ]]; then
  ACUTS="EVNDISP.reconstruction.runparameter.NN.v4x"
elif [[ $ANATYPE = "CC"* ]]; then
  ACUTS="EVNDISP.reconstruction.runparameter.CC.v4x"
elif [[ $ANATYPE = "TS"* ]]; then
  ACUTS="EVNDISP.reconstruction.runparameter.TS.v4x"
fi

# default cut list files
if [ -z "$CUTSLISTFILE" ]; then
    if [[ ${SIMTYPE} == *"RedHV"* ]]; then
        CUTSLISTFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS_RedHV_${ANATYPE}.dat"
    elif [[ ${SIMTYPE} == *"UV"* ]]; then
        CUTSLISTFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS_UV_${ANATYPE}.dat"
    elif [[ ${IRFTYPE} == *"PRESELECT"* ]]; then
        CUTSLISTFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS_PRESELECTION_${ANATYPE}.dat"
    else
        CUTSLISTFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS_${ANATYPE}.dat"
    fi
fi
# Modify by hand for extended cuts
# CUTSLISTFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/IRF_GAMMAHADRONCUTS_${ANATYPE}_EXTENDED_CUTS.dat"

echo "Cut list file: $CUTSLISTFILE"
echo "Simulation type: $SIMTYPE"

# simulation space and learner-specific training parameter spaces
SIM_ZENITH_ANGLES=()
SIM_NSB_LEVELS=()
SIM_WOBBLE_OFFSETS=()
TRAIN_TMVA_GH_ZENITH_ANGLES=()
TRAIN_TMVA_GH_NSB_LEVELS=()
TRAIN_TMVA_GH_WOBBLE_OFFSETS=()
TRAIN_XGB_GH_ZENITH_ANGLES=()
TRAIN_XGB_GH_NSB_LEVELS=()
TRAIN_XGB_GH_WOBBLE_OFFSETS=()
TRAIN_MVA_ANGRES_NSB_LEVELS=()
TRAIN_MVA_ANGRES_WOBBLE_OFFSETS=()
TRAIN_XGB_ANGRES_ZENITH_ANGLES=()
TRAIN_XGB_ANGRES_NSB_LEVELS=()
TRAIN_XGB_ANGRES_WOBBLE_OFFSETS=()
TRAIN_XGB_ANGRES_BIN_IDS=()

set_gh_training_parameter_space()
{
    TRAIN_TMVA_GH_ZENITH_ANGLES=( 20 30 35 40 45 50 55 60 65 )
    TRAIN_TMVA_GH_WOBBLE_OFFSETS=( 0.5 )
    TRAIN_XGB_GH_WOBBLE_OFFSETS=( 0.5 )
    if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
        TRAIN_TMVA_GH_NSB_LEVELS=( 100 150 200 250 325 425 550 )
    else
        TRAIN_TMVA_GH_NSB_LEVELS=( 100 160 200 250 350 450 )
    fi

    TRAIN_XGB_GH_ZENITH_ANGLES=()
    TRAIN_XGB_GH_NSB_LEVELS=()
    XGB_GH_RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-classify-parameter.json"
    if [[ -f "$XGB_GH_RUNPAR" ]]; then
        mapfile -t TRAIN_XGB_GH_ZENITH_ANGLES < <(jq -r '.input_zenith_angles[]' "$XGB_GH_RUNPAR")
        mapfile -t TRAIN_XGB_GH_NSB_LEVELS < <(jq -r '.input_noise_values[]' "$XGB_GH_RUNPAR")
    fi
}

set_angres_training_parameter_space()
{
    TRAIN_XGB_ANGRES_ZENITH_ANGLES=()
    TRAIN_XGB_ANGRES_NSB_LEVELS=( 160 200 350 450 )
    TRAIN_XGB_ANGRES_WOBBLE_OFFSETS=( 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 )
    TRAIN_XGB_ANGRES_BIN_IDS=()

    STEREO_PAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-stereo-parameter.json"
    if [[ -f "$STEREO_PAR" ]]; then
        mapfile -t TRAIN_XGB_ANGRES_ZENITH_ANGLES < <(jq -r '.zenith[].train[]' "$STEREO_PAR" | sort -un | awk '{printf "%02d\n", $1}')
        mapfile -t TRAIN_XGB_ANGRES_BIN_IDS < <(jq -r '.zenith[].id' "$STEREO_PAR")
    fi

    TRAIN_MVA_ANGRES_WOBBLE_OFFSETS=( 0.25 0.5 0.75 1.0 1.5 )
    if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
        TRAIN_MVA_ANGRES_NSB_LEVELS=( 150 200 250 )
        TRAIN_MVA_ANGRES_WOBBLE_OFFSETS=( 0.25 0.5 0.75 1.00 1.50 )
    elif [[ ${SIMTYPE} = "CARE_RedHV" ]]; then
        TRAIN_MVA_ANGRES_NSB_LEVELS=( 300 600 900 )
        TRAIN_MVA_ANGRES_WOBBLE_OFFSETS=( 0.5 )
    elif [[ ${SIMTYPE} = "CARE_RedHV_"* ]]; then
        TRAIN_MVA_ANGRES_NSB_LEVELS=( 300 600 900 )
    elif [[ ${SIMTYPE} = "CARE_UV"* ]]; then
        TRAIN_MVA_ANGRES_NSB_LEVELS=( 160 200 300 )
        TRAIN_MVA_ANGRES_WOBBLE_OFFSETS=( 0.5 )
    elif [[ ${SIMTYPE:0:4} = "CARE" ]]; then
        TRAIN_MVA_ANGRES_NSB_LEVELS=( 160 200 250 )
    fi
}

set_sim_parameter_space()
{
    if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
        # GrISU simulation parameters
        SIMDIR=${VERITAS_DCACHE_DIR}/simulations/"$VX"_FLWO/grisu/ATM"$ATM"
        SIM_ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 60 65 )
        SIM_NSB_LEVELS=( 075 100 150 200 250 325 425 550 750 1000 )
        SIM_WOBBLE_OFFSETS=( 0.5 0.00 0.25 0.75 1.00 1.25 1.50 1.75 2.00 )
        if [[ $IRFTYPE == "MVAEVNDISP" ]]; then
           SIM_NSB_LEVELS=( 200 )
           SIM_WOBBLE_OFFSETS=( 0.5 )
        fi
    elif [ "${SIMTYPE}" = "CARE_June1702" ]; then
        SIMDIR="${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1702/"
        if [[ $ATMOS == "62" ]]; then
            SIM_ZENITH_ANGLES=( 00 30 50 )
        else
            SIM_ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 )
        fi
        SIM_NSB_LEVELS=( 50 75 100 130 160 200 250 300 350 400 450 )
        SIM_WOBBLE_OFFSETS=( 0.5 )
    elif [ "${SIMTYPE}" == "CARE_UV_June1409" ]; then
        SIMDIR=${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1409_UV/
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -maxdepth 1 -name "*.bz2" -exec basename {} \; | awk -F "gamma_" '{print $2}' | awk -F "deg." '{print $1}' | sort -u)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}" -maxdepth 1 -name "*.bz2" -exec basename {} \; | awk -F "wob_" '{print $2}' | awk -F "mhz." '{print $1}' | sort -u)
        SIM_WOBBLE_OFFSETS=( 0.5 )
    elif [ "${SIMTYPE}" == "CARE_UV_2212" ]; then
        SIMDIR=${VERITAS_DATA_DIR}/simulations/UVF_Dec2022/CARE/
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -maxdepth 1 -name "*.zst" -exec basename {} \; | awk -F "_zen" '{print $2}' | awk -F "deg." '{print $1}' | sort -u)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}" -maxdepth 1 -name "*.zst" -exec basename {} \; | awk -F "wob_" '{print $2}' | awk -F "MHz." '{print $1}' | sort -u)
        mapfile -t SIM_WOBBLE_OFFSETS < <(find "${SIMDIR}" -maxdepth 1 -name "*.zst" -exec basename {} \; | awk -F "_" '{print $8}' | awk -F "wob" '{print $1}' | sort -u)
    elif [ "${SIMTYPE}" == "CARE_RedHV" ]; then
        SIMDIR="${VERITAS_DCACHE_DIR}/simulations/V6_FLWO/CARE_June1702_RHV/ATM${ATMOS}"
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -maxdepth 1 -name "*.zst" -exec basename {} \; | awk -F "_zen" '{print $2}' | awk -F "deg." '{print $1}' | sort -u)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}" -maxdepth 1 -name "*.zst" -exec basename {} \; | awk -F "wob_" '{print $2}' | awk -F "MHz." '{print $1}' | sort -u)
        SIM_WOBBLE_OFFSETS=( 0.5 )
    elif [[ "${SIMTYPE}" == "CARE_June2020" ]]; then
        SIMDIR="${VERITAS_DATA_DIR}/shared/simulations/NSOffsetSimulations/Atmosphere${ATMOS}"
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -mindepth 1 -maxdepth 1 -type d -name "Zd*" -exec basename {} \; | awk -F "Zd" '{print $2}' | sort -u)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}" -path '*/Zd*/*' -type f -exec basename {} \; | awk -F "_" '{print $8}' | awk -F "MHz" '{print $1}' | sort -u)
        mapfile -t SIM_WOBBLE_OFFSETS < <(find "${SIMDIR}" -path '*/Zd*/*' -type f -exec basename {} \; | awk -F "_" '{print $7}' | awk -F "wob" '{print $1}' | sort -u)
    elif [[ "${SIMTYPE}" == "CARE_RedHV_Feb2024" ]]; then
        SIMDIR="${VERITAS_DCACHE_DIR}/simulations/NSOffsetSimulations_redHV/Atmosphere${ATMOS}"
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -mindepth 1 -maxdepth 1 -type d -name "Zd*" -exec basename {} \; | awk -F "Zd" '{print $2}' | grep -v curved | sort -u)
        ze_first_bin=$(printf '%s\n' "${SIM_ZENITH_ANGLES[@]}" | head -n 1)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}/Zd${ze_first_bin}" -maxdepth 1 -type f -name "*.zst" -exec basename {} \; | sed -nE 's/.*_([0-9.]+)wob_([0-9]+)MHz.*/\2/p' | sort -u)
        mapfile -t SIM_WOBBLE_OFFSETS < <(find "${SIMDIR}/Zd${ze_first_bin}" -maxdepth 1 -type f -name "*.zst" -exec basename {} \; | sed -nE 's/.*_([0-9.]+)wob_([0-9]+)MHz.*/\1/p' | sort -u)
    elif [[ "${SIMTYPE}" == "CARE_202404" ]] || [[ "${SIMTYPE}" == "CARE_24_20" ]]; then
        SIMDIR="${VERITAS_DCACHE_DIR}/simulations/NSOffsetSimulations_202404/Atmosphere${ATMOS}"
        mapfile -t SIM_ZENITH_ANGLES < <(find "${SIMDIR}" -mindepth 1 -maxdepth 1 -type d -name "Zd*" -exec basename {} \; | awk -F "Zd" '{print $2}' | grep -v curved | sort -u)
        ze_first_bin=$(printf '%s\n' "${SIM_ZENITH_ANGLES[@]}" | head -n 1)
        mapfile -t SIM_NSB_LEVELS < <(find "${SIMDIR}/Zd${ze_first_bin}" -maxdepth 1 -type f -name "*.zst" -exec basename {} \; | sed -nE 's/.*_([0-9.]+)wob_([0-9]+)MHz.*/\2/p' | sort -u)
        mapfile -t SIM_WOBBLE_OFFSETS < <(find "${SIMDIR}/Zd${ze_first_bin}" -maxdepth 1 -type f -name "*.zst" -exec basename {} \; | sed -nE 's/.*_([0-9.]+)wob_([0-9]+)MHz.*/\1/p' | sort -u)
    elif [ "${SIMTYPE:0:4}" == "CARE" ]; then
        # Older CARE simulation parameters
        SIMDIR=$VERITAS_DATA_DIR/simulations/"${VX:0:2}"_FLWO/CARE_June1425/
        SIM_ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 60 65 )
        SIM_NSB_LEVELS=( 50 80 120 170 230 290 370 450 )
        SIM_WOBBLE_OFFSETS=( 0.5 )
        if [[ $IRFTYPE == "MVAEVNDISP" ]]; then
           SIM_NSB_LEVELS=( 170 )
           SIM_WOBBLE_OFFSETS=( 0.5 )
        fi
    else
        echo "Invalid simulation type: ${SIMTYPE}. Exiting..."
        exit 1
    fi
}

use_parameter_space()
{
    case "$1" in
        sim)
            ZENITH_ANGLES=( "${SIM_ZENITH_ANGLES[@]}" )
            NSB_LEVELS=( "${SIM_NSB_LEVELS[@]}" )
            WOBBLE_OFFSETS=( "${SIM_WOBBLE_OFFSETS[@]}" )
            ;;
        xgb-angres)
            ZENITH_ANGLES=( "${TRAIN_XGB_ANGRES_ZENITH_ANGLES[@]}" )
            NSB_LEVELS=( "${TRAIN_XGB_ANGRES_NSB_LEVELS[@]}" )
            WOBBLE_OFFSETS=( "${TRAIN_XGB_ANGRES_WOBBLE_OFFSETS[@]}" )
            ;;
        *)
            echo "Unknown parameter space '$1'"
            exit 1
            ;;
    esac
}

irftype_requires_sim_parameter_space()
{
    case "$1" in
        EVNDISP|MVAEVNDISP|EVNDISPCOMPRESS|MAKETABLES|ANALYSETABLES|ANALYSETABLESXGBTRAIN|ANATABLESEFFAREAS|EFFECTIVEAREAS|PRESELECTEFFECTIVEAREAS|TRAINMVANGRES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# read cut list file
read_cutlist()
{
    CUTFILE="${1}"
    if [[ $CUTFILE == "" ]] || [ ! -f "$CUTFILE" ]; then
        echo "Error, cuts list file not found, exiting..." >&2
        echo "$CUTFILE"
        exit 1
    fi
    CUTLISTFROMFILE=$(cat "$CUTFILE")
    CUTLIST=""
    for CUT in "${CUTLISTFROMFILE[@]}"; do
        CUTLIST="${CUTLIST} ANASUM.GammaHadron-Cut-$CUT.dat"
    done
    echo "${CUTLIST# }"
}

# Cut types are used for BDT training and optimisation
CUTTYPES=(
    "NTel2-PointSource-Moderate"
    "NTel2-PointSource-Soft"
    "NTel2-PointSource-Hard"
    "NTel3-PointSource-Hard"
)
# NN cuts for soft only
if [[ $ANATYPE = "NN"* ]]; then
    CUTTYPES=("NTel2-PointSource-SuperSoft")
fi

echo "===== Start submission ====="

############################################################
# loop over complete parameter space and submit production
for VX in $EPOCH; do
    for ATM in $ATMOS; do
       ######################
       # set lookup table file name
       TABLECOM="table-${EDVERSION}-${AUX}-${SIMTYPE}-ATM${ATM}-${VX}-"
       ######################
       # combine lookup tables
       if [[ $IRFTYPE == "COMBINETABLES" ]]; then
            TFIL="${TABLECOM}"
            for ID in $RECID; do
                echo "combine lookup tables"
                "$(dirname "$0")/IRF.combine_lookup_table_parts.sh" \
                    "${TFIL}${ANATYPE}" "$VX" "$ATM" \
                    "$ID" "$SIMTYPE" "$ANATYPE"
            done
            continue
       fi
       ######################
       # combine effective areas
       if [[ $IRFTYPE == "COMBINEEFFECTIVEAREAS" ]] || [[ $IRFTYPE == "COMBINEPRESELECTEFFECTIVEAREAS" ]]; then
            CUTLIST=$(read_cutlist "$CUTSLISTFILE")
            echo "CUTLIST: $CUTLIST"
            for ID in $RECID; do
                for CUTS in "${CUTLIST[@]}"; do
                    echo "combine effective areas $CUTS"
                   "$(dirname "$0")/IRF.combine_effective_area_parts.sh" \
                       "$CUTS" "$VX" "$ATM" \
                       "$ID" "$SIMTYPE" "$AUX" "$ANATYPE" \
                       "$DISPBDT"
                done # cuts
            done
            continue
       fi
       #############################################
       # Analyse XGBs based on MSCW files (directory, energy)
       if [[ $IRFTYPE == "ANAXGBANGRES" ]]; then
            MSCWDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANATYPE}/${SIMTYPE}/${VX}_ATM${ATM}_gamma/MSCW_RECID${RECID}_DISP"
            echo "XGB reconstruction reading from $MSCWDIR"
            "$(dirname "$0")/IRF.dispXGB.sh" "stereo_analysis" "${MSCWDIR}" "${MSCWDIR}"
            continue
       fi
       #############################################
       # Classification XGB based on MSCW files
       if [[ $IRFTYPE == "ANAXGBGH" ]]; then
            MSCWDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANATYPE}/${SIMTYPE}/${VX}_ATM${ATM}_gamma/MSCW_RECID${RECID}_DISP"
            echo "XGB classification reading from $MSCWDIR"
            "$(dirname "$0")/IRF.dispXGB.sh" "classification" "${MSCWDIR}" "${MSCWDIR}"
            continue
       fi
       #############################################
       # XGB Classification Training
       if [[ $IRFTYPE == "TRAINXGBGH" ]]; then
           set_gh_training_parameter_space
           BCKDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANATYPE}/BDTtraining/mscw_${VX:0:2}_XGB"
           RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/XGB-classify-parameter.json"
           ODIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANATYPE}/${SIMTYPE}/${VX}_ATM${ATM}_gamma/TrainXGBGammaHadron"
           echo "XGB Classification Training"
           echo "${BCKDIR}" "${RUNPAR}" "${ODIR}" "${SIMTYPE}" "${VX}" "${ATM}"
           "$(dirname "$0")/IRF.trainXGBforGammaHadronSeparationTraining.sh" \
               "${BCKDIR}" "${RUNPAR}" "${ODIR}" "${SIMTYPE}" "${VX}" "${ATM}" \
               "${UUID}" "${TRAIN_XGB_GH_ZENITH_ANGLES[*]}" "${TRAIN_XGB_GH_NSB_LEVELS[*]}" "${TRAIN_XGB_GH_WOBBLE_OFFSETS[*]}"
           continue
       fi
       #############################################
       # MVA training
       # train per epoch and atmosphere and for each cut
       # (cut as sizesecondmax cut is applied)
       if [[ $IRFTYPE == "TRAINTMVA" ]] || [[ $IRFTYPE == "OPTIMIZETMVA" ]]; then
            set_gh_training_parameter_space
            for C in "${CUTTYPES[@]}"; do
                echo "Training/optimising TMVA for $C cuts, ${VX} ATM${ATM}"
                BDTDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/${ANATYPE}/BDTtraining"
                MVADIR="${BDTDIR}/GammaHadronBDTs_${VX:0:2}/${VX}_ATM${ATM}/${C/PointSource-/}/"
                # list of background files
                TRAINDIR="${BDTDIR}/mscw_${VX:0:2}/"
                if [[ $DISPBDT == "1" ]]; then
                    TRAINDIR="${BDTDIR}/mscw_${VX:0:2}_DISP/"
                    MVADIR="${BDTDIR}/GammaHadronBDTs_${VX:0:2}_DISP/${VX}_ATM${ATM}/${C/PointSource-/}/"
                fi
                mkdir -p -v "${MVADIR}"
                if [[ $IRFTYPE == "TRAINTMVA" ]]; then
                    # retrieve size cut
                    CUTFIL="$VERITAS_EVNDISP_AUX_DIR"/GammaHadronCutFiles/ANASUM.GammaHadron-Cut-${C}-TMVA-Preselection.dat
                    echo "CUTFILE: $CUTFIL"
                    SIZECUT=$(grep '^\* sizesecondmax' "$CUTFIL" | grep "${VX:0:2}" | awk '{print $3}' | sort -u)
                    if [ -z "$SIZECUT" ]
                    then
                        echo "No size cut found; skipping cut $C"
                        continue
                    fi
                    echo "Size cut applied: $SIZECUT"
                    RUNPAR="TMVA.BDT.runparameter"
                    if [[ ${VX:0:2} == "V4" ]] || [[ ${VX:0:2} == "V5" ]]; then
                        cp -f "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/TMVA.BDT.V4.runparameter "$MVADIR"/"$RUNPAR"
                    else
                        cp -f "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/"$RUNPAR" "$MVADIR"/"$RUNPAR"
                    fi
                    sed -i "s/TMVASIZECUT/${SIZECUT}/" "$MVADIR"/"$RUNPAR"
                    if [[ $CUTFIL = *"NTel3"* ]]; then
                        sed -i "s/NImages>1/NImages>2/" "$MVADIR"/"$RUNPAR"
                    fi
                    "$(dirname "$0")/IRF.trainTMVAforGammaHadronSeparation.sh" \
                                 "${TRAINDIR}" \
                                 "$MVADIR"/"$RUNPAR" \
                                 "${MVADIR}" BDT "${SIMTYPE}" "${VX}" "${ATM}" \
                                 "${UUID}" "${TRAIN_TMVA_GH_ZENITH_ANGLES[*]}" "${TRAIN_TMVA_GH_NSB_LEVELS[*]}" "${TRAIN_TMVA_GH_WOBBLE_OFFSETS[*]}"
                 # Cut optimization
                 elif [[ $IRFTYPE == "OPTIMIZETMVA" ]]; then
                     echo "OPTIMIZE TMVA $C ${BDTDIR}/BackgroundRates/${VX:0:2}"
                     "$(dirname "$0")/IRF.optimizeTMVAforGammaHadronSeparation.sh" \
                         "${BDTDIR}/BackgroundRates/${VX:0:2}" \
                         "${C/PointSource-/}" \
                         "${SIMTYPE}" "${VX}" "${ATM}"
                 fi
            done
            continue
       fi
       #################################################
       # zenith angle bin dependent analysis
       #################################################
       if [[ $IRFTYPE == "TRAINXGBANGRES" ]]; then
           set_angres_training_parameter_space
           for ZAB in "${TRAIN_XGB_ANGRES_BIN_IDS[@]}"; do
                   "$(dirname "$0")/IRF.trainXGBforAngularReconstruction.sh" \
                       "$VX" "$ATM" "$ZAB" "${TRAIN_XGB_ANGRES_WOBBLE_OFFSETS[*]}" "${TRAIN_XGB_ANGRES_NSB_LEVELS[*]}" 0 \
                       "$SIMTYPE" "$ANATYPE" "$UUID"
           done
           continue
       fi
       if irftype_requires_sim_parameter_space "$IRFTYPE"; then
           set_sim_parameter_space
           if [[ $IRFTYPE == "ANALYSETABLESXGBTRAIN" ]]; then
               set_angres_training_parameter_space
               use_parameter_space xgb-angres
           else
               use_parameter_space sim
           fi
           echo "Zenith angle bins: ${ZENITH_ANGLES}"
           echo "NSB levels: ${NSB_LEVELS}"
           echo "Wobble offsets: ${WOBBLE_OFFSETS}"
       fi
    # zenith angle dependent analysis
    for ZA in ${ZENITH_ANGLES[@]}; do
            ######################
            # train MVA for angular resolution
            if [[ $IRFTYPE == "TRAINMVANGRES" ]]; then
               set_angres_training_parameter_space
               "$(dirname "$0")/IRF.trainTMVAforAngularReconstruction.sh" \
                   "$VX" "$ATM" "$ZA" "${TRAIN_MVA_ANGRES_WOBBLE_OFFSETS[*]}" "${TRAIN_MVA_ANGRES_NSB_LEVELS[*]}" 0 \
                   "$SIMTYPE" "$ANATYPE" "$UUID"
               continue
            fi
            for NOISE in ${NSB_LEVELS[@]}; do
                for WOBBLE in ${WOBBLE_OFFSETS[@]}; do
                    echo "Preparing epoch $VX, atmo $ATM, zenith $ZA, wobble $WOBBLE, noise $NOISE"
                    ######################
                    # run simulations through evndisp
                    if [[ $IRFTYPE == "EVNDISP" ]] || [[ $IRFTYPE == "MVAEVNDISP" ]] || [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                       SIMDIRZA="$SIMDIR"
                       # CURVED_ATMOSPHERE_MC
                       # if [[ -e "$SIMDIR/Zd${ZA}_curved/" ]]; then
                       #   SIMDIRZA="$SIMDIR/Zd${ZA}_curved/"
                       #    echo "Using curved atmosphere simulations from $SIMDIRZA"
                       if [[ -e "$SIMDIR/Zd${ZA}/" ]]; then
                          SIMDIRZA="$SIMDIR/Zd${ZA}/"
                          echo "Using flat atmosphere simulations from $SIMDIRZA"
                       fi
                       if [[ $IRFTYPE == "EVNDISP" ]]; then
                           "$(dirname "$0")/IRF.evndisp_MC.sh" \
                               "$SIMDIRZA" "$VX" "$ATM" "$ZA" "$WOBBLE" "$NOISE" \
                               "$SIMTYPE" $ACUTS 1 "$ANATYPE" "$UUID"
                       elif [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                           "$(dirname "$0")/IRF.compress_evndisp_MC.sh" \
                               "$SIMDIRZA" "$VX" "$ATM" "$ZA" "$WOBBLE" "$NOISE" \
                               "$SIMTYPE" "$ANATYPE" "$UUID"
                       fi
                    ######################
                    # make tables
                    elif [[ $IRFTYPE == "MAKETABLES" ]]; then
                        for ID in $RECID; do
                           "$(dirname "$0")/IRF.generate_lookup_table_parts.sh" \
                               "$VX" "$ATM" "$ZA" "$WOBBLE" "$NOISE" \
                               "$ID" "$SIMTYPE" "$ANATYPE" "$UUID"
                        done #recID
                    ######################
                    # analyse table files
elif [[ $IRFTYPE == "ANALYSETABLES" ]] || [[ $IRFTYPE == "ANALYSETABLESXGBTRAIN" ]] || [[ $IRFTYPE == "ANATABLESEFFAREAS" ]]; then
                        for ID in $RECID; do
                            TFIL="${TABLECOM}"
                            # note: the IDs dependent on what is written in EVNDISP.reconstruction.runparameter
                            TFILID=$TFIL$ANATYPE
                            # run mscw only
                            EFFAREACUTLIST="NOEFFAREA"
                            if [[ $IRFTYPE == "ANATABLESEFFAREAS" ]]; then
                                # run mscw and effective area code
                                EFFAREACUTLIST="$CUTSLISTFILE"
                            fi
                            "$(dirname "$0")/IRF.mscw_energy_MC.sh" \
                                "$TFILID" "$VX" "$ATM" "$ZA" "$WOBBLE" "$NOISE" \
                                "$ID" "$SIMTYPE" "$ANATYPE" $DISPBDT "$EFFAREACUTLIST" "$UUID"
			            done #recID
                    ######################
                    # analyse effective areas
                    elif [[ $IRFTYPE == "EFFECTIVEAREAS" ]] || [[ $IRFTYPE == "PRESELECTEFFECTIVEAREAS" ]]; then
                        CUTLIST=$(read_cutlist "$CUTSLISTFILE")
                        echo "CUTLIST: $CUTLIST"
                        for ID in ${RECID}; do
                            for CUTS in "${CUTLIST[@]}"; do
                               echo "calculate effective areas $CUTS (ID $ID)"
                               "$(dirname "$0")/IRF.generate_effective_area_parts.sh" \
                                   "$CUTS" "$VX" "$ATM" "$ZA" "$WOBBLE" "$NOISE" \
                                   "$ID" "$SIMTYPE" "$ANATYPE" \
                                   $DISPBDT "$UUID"
                            done # cuts
                        done #recID
                    fi
                done #wobble
            done #noise
        done #ZA
    done #ATM
done  #VX

# Go back to the original user directory.
cd "$olddir" || exit
exit
