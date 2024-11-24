#!/bin/bash
# IRF production script (VERITAS)

# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 2 ]; then
echo "
IRF generation: produce a full set of instrument response functions (IRFs)

IRF.production.sh <sim type> <IRF type> [epoch] [atmosphere] [Rec ID] [cuts list file] [sim directory]

required parameters:

    <sim type>              simulation type
                            (e.g. GRISU, CARE_June2020, CARE_RedHV, CARE_UV,
                            CARE_RedHV_Feb2024, CARE_202404, CARE_24_20)

    <IRF type>              type of instrument response function to produce
                            (e.g. EVNDISP, MAKETABLES, COMBINETABLES,
                             (ANALYSETABLES, PRESELECTEFFECTIVEAREAS, EFFECTIVEAREAS,
                             ANATABLESEFFAREAS, COMBINEPRESELECTEFFECTIVEAREAS, COMBINEEFFECTIVEAREAS,
                             MVAEVNDISP, TRAINTMVA, OPTIMIZETMVA,
                             TRAINMVANGRES, EVNDISPCOMPRESS)

optional parameters:

    [epoch]                 array epoch(s) (e.g., V4, V5, V6)
                            (default: \"V4 V5 V6\")
                            (V6 epochs: e.g., \"V6_2012_2013a V6_2012_2013b V6_2013_2014a V6_2013_2014b
                             V6_2014_2015 V6_2015_2016 V6_2016_2017 V6_2017_2018 V6_2018_2019 V6_2019_2020
                             V6_2019_2020w V6_2020_2020s V6_2020_2021w V6_2021_2021s V6_2021_2022w
                             V6_2022_2022s, V6_2022_2023w, V6_2023_2023s, V6_2023_2024w\")

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
cd $(dirname "$0")

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

# Parse command line arguments
SIMTYPE="$1"
IRFTYPE="$2"
[[ "$3" ]] && EPOCH="$3" || EPOCH="V6 V5 V4"
[[ "$4" ]] && ATMOS="$4" || ATMOS="61 62"
[[ "$5" ]] && RECID="$5" || RECID="0"
[[ "$6" ]] && CUTSLISTFILE="$6" || CUTSLISTFILE=""
[[ "$7" ]] && SIMDIR="$7" || SIMDIR=""

# uuid for this job batch
DATE=`date +"%y%m%d"`
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

echo "CUT LIST FILE: $CUTSLISTFILE"

# simulation types and definition of parameter space
if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
    # GrISU simulation parameters
    ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 60 65 )
    NSB_LEVELS=( 075 100 150 200 250 325 425 550 750 1000 )
    WOBBLE_OFFSETS=( 0.5 0.00 0.25 0.75 1.00 1.25 1.50 1.75 2.00 )
    if [[ $IRFTYPE == "MVAEVNDISP" ]]; then
       NSB_LEVELS=( 200 )
       WOBBLE_OFFSETS=( 0.5 )
    fi
elif [ "${SIMTYPE}" = "CARE_June1702" ]; then
    SIMDIR="${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1702/"

    if [[ $ATMOS == "62" ]]; then
        ZENITH_ANGLES=( 00 30 50 )
    else
        ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 )
    fi
    NSB_LEVELS=( 50 75 100 130 160 200 250 300 350 400 450 )
    WOBBLE_OFFSETS=( 0.5 )
elif [ "${SIMTYPE}" == "CARE_UV_June1409" ]; then
    SIMDIR=${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1409_UV/
    ZENITH_ANGLES=$(ls ${SIMDIR}/*.bz2 | awk -F "gamma_" '{print $2}' | awk -F "deg." '{print $1}' | sort | uniq)
    NSB_LEVELS=$(ls ${SIMDIR}/*.bz2 | awk -F "wob_" '{print $2}' | awk -F "mhz." '{print $1}' | sort | uniq)
    WOBBLE_OFFSETS=( 0.5 )
elif [ "${SIMTYPE}" == "CARE_UV_2212" ]; then
    SIMDIR=${VERITAS_DATA_DIR}/simulations/UVF_Dec2022/CARE/
    ZENITH_ANGLES=$(ls ${SIMDIR}/*.zst | awk -F "_zen" '{print $2}' | awk -F "deg." '{print $1}' | sort | uniq)
    NSB_LEVELS=$(ls ${SIMDIR}/*.zst | awk -F "wob_" '{print $2}' | awk -F "MHz." '{print $1}' | sort | uniq)
    WOBBLE_OFFSETS=$(ls ${SIMDIR}/*.zst | awk -F "_" '{print $8}' |  awk -F "wob" '{print $1}' | sort -u)
elif [ "${SIMTYPE}" == "CARE_RedHV" ]; then
    SIMDIR="${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1702_RHV/ATM${ATMOS}"
    ZENITH_ANGLES=$(ls ${SIMDIR}/*.zst | awk -F "_zen" '{print $2}' | awk -F "deg." '{print $1}' | sort | uniq)
    NSB_LEVELS=$(ls ${SIMDIR}/*.zst | awk -F "wob_" '{print $2}' | awk -F "MHz." '{print $1}' | sort | uniq)
    WOBBLE_OFFSETS=( 0.5 )
elif [[ "${SIMTYPE}" == "CARE_June2020" ]]; then
    SIMDIR="${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations/Atmosphere${ATMOS}"
    ZENITH_ANGLES=$(ls ${SIMDIR} | awk -F "Zd" '{print $2}' | sort | uniq)
    set -- $ZENITH_ANGLES
    NSB_LEVELS=$(ls ${SIMDIR}/Zd*/* | awk -F "_" '{print $8}' | awk -F "MHz" '{print $1}'| sort -u)
    WOBBLE_OFFSETS=$(ls ${SIMDIR}/Zd*/* | awk -F "_" '{print $7}' |  awk -F "wob" '{print $1}' | sort -u)
    ######################################
    # TEST
    # ZENITH_ANGLES=( 20 )
    # WOBBLE_OFFSETS=( 0.5 )
    # NSB_LEVELS=( 200 )
    ######################################
    # TRAINMVANGRES production
    # (assume 0.5 deg wobble is done)
    # NSB_LEVELS=( 160 200 250 )
    # WOBBLE_OFFSETS=( 0.25 0.75 1.0 1.5 )
    # complete NSB bins from TRAINMVANGRES production
    # (assume 0.5 deg wobble is done)
    # NSB_LEVELS=( 50 75 100 130 300 350 400 450 )
    # WOBBLE_OFFSETS=( 0.25 0.75 1.0 1.5 )
    # complete wobble bins after TRAINMVANGRES production
    # WOBBLE_OFFSETS=( 0.0 1.25 1.75 2.0 )
    # (END TEMPORARY)
    ######################################
elif [[ "${SIMTYPE}" == "CARE_RedHV_Feb2024" ]]; then
    SIMDIR="${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations_redHV/Atmosphere${ATMOS}"
    ZENITH_ANGLES=$(ls ${SIMDIR} | awk -F "Zd" '{print $2}' | sort | uniq)
    set -- $ZENITH_ANGLES
    NSB_LEVELS=$(ls ${SIMDIR}/*/* | awk -F "_" '{print $9}' | awk -F "MHz" '{print $1}'| sort -u)
    WOBBLE_OFFSETS=$(ls ${SIMDIR}/*/* | awk -F "_" '{print $8}' |  awk -F "wob" '{print $1}' | sort -u)
    ######################################
    # TEST
    # NSB_LEVELS=( 300 )
    # ZENITH_ANGLES=( 20 )
    # WOBBLE_OFFSETS=( 0.5 )
elif [[ "${SIMTYPE}" == "CARE_202404" ]] || [[ "${SIMTYPE}" == "CARE_24_20" ]]; then
    SIMDIR="${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations_202404/Atmosphere${ATMOS}"
    ZENITH_ANGLES=$(ls ${SIMDIR} | awk -F "Zd" '{print $2}' | sort | uniq)
    set -- $ZENITH_ANGLES
    ze_first_bin=$(echo $ZENITH_ANGLES | awk '{print $1}')
    # assume sanme NSB and wobble offsets in all bins
    NSB_LEVELS=$(ls ${SIMDIR}/*${ze_first_bin}*/* | awk -F "_" '{print $9}' | awk -F "MHz" '{print $1}'| sort -u)
    WOBBLE_OFFSETS=$(ls ${SIMDIR}/*${ze_first_bin}*/* | awk -F "_" '{print $8}' |  awk -F "wob" '{print $1}' | sort -u)
    ######################################
    # TEST
    # NSB_LEVELS=( 200 )
    # ZENITH_ANGLES=( 20 )
    # WOBBLE_OFFSETS=( 0.5 )
elif [ ${SIMTYPE:0:4} == "CARE" ]; then
    # Older CARE simulation parameters
    SIMDIR=$VERITAS_DATA_DIR/simulations/"${VX:0:2}"_FLWO/CARE_June1425/
    ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 60 65 )
    NSB_LEVELS=( 50 80 120 170 230 290 370 450 )
    WOBBLE_OFFSETS=( 0.5 )
    if [[ $IRFTYPE == "MVAEVNDISP" ]]; then
       NSB_LEVELS=( 170 )
       WOBBLE_OFFSETS=( 0.5 )
    fi
else
    echo "Invalid simulation type: ${SIMTYPE}. Exiting..."
    exit 1
fi
echo "Zenith Angles: ${ZENITH_ANGLES}"
echo "NSB levels: ${NSB_LEVELS}"
echo "Wobble offsets: ${WOBBLE_OFFSETS}"



# read cut list file
read_cutlist()
{
    CUTFILE="${1}"
    if [[ $CUTFILE == "" ]] || [ ! -f $CUTFILE ]; then
        echo "Error, cuts list file not found, exiting..." >&2
        echo $CUTFILE
        exit 1
    fi
    CUTLISTFROMFILE=$(cat $CUTFILE)
    CUTLIST=""
    for CUT in ${CUTLISTFROMFILE[@]}; do
        CUTLIST="${CUTLIST} ANASUM.GammaHadron-Cut-$CUT.dat"
    done
    echo $CUTLIST
}

# Cut types are used for BDT training and optimisation
CUTTYPES="NTel2-PointSource-Moderate
          NTel2-PointSource-Soft
          NTel2-PointSource-Hard
          NTel3-PointSource-Hard"
# NN cuts for soft only
if [[ $ANATYPE = "NN"* ]]; then
    CUTTYPES="NTel2-PointSource-SuperSoft"
fi
CUTTYPES=`echo $CUTTYPES |tr '\r' ' '`
CUTTYPES=${CUTTYPES//$'\n'/}


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
                $(dirname "$0")/IRF.combine_lookup_table_parts.sh \
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
                for CUTS in ${CUTLIST[@]}; do
                    echo "combine effective areas $CUTS"
                   $(dirname "$0")/IRF.combine_effective_area_parts.sh \
                       "$CUTS" "$VX" "$ATM" \
                       "$ID" "$SIMTYPE" "$AUX" "$ANATYPE" \
                       "$DISPBDT"
                done # cuts
            done
            continue
       fi
       #############################################
       # MVA training
       # train per epoch and atmosphere and for each cut
       # (cut as sizesecondmax cut is applied)
       if [[ $IRFTYPE == "TRAINTMVA" ]] || [[ $IRFTYPE == "OPTIMIZETMVA" ]]; then
            for VX in $EPOCH; do
                for ATM in $ATMOS; do
                    for C in ${CUTTYPES[@]}; do
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
                            SIZECUT=`grep "* sizesecondmax" $CUTFIL | grep ${EPOCH:0:2} | awk '{print $3}' | sort -u`
                            if [ -z "$SIZECUT" ]
                            then
                                echo "No size cut found; skipping cut $C"
                                continue
                            fi
                            echo "Size cut applied: $SIZECUT"
                            if [[ ${EPOCH:0:2} == "V4" ]] || [[ ${EPOCH:0:2} == "V5" ]]; then
                                cp -f "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/TMVA.BDT.V4.runparameter "$MVADIR"/BDT.runparameter
                            else
                                cp -f "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/TMVA.BDT.runparameter "$MVADIR"/BDT.runparameter
                            fi
                            sed -i "s/TMVASIZECUT/${SIZECUT}/" "$MVADIR"/BDT.runparameter
                            if [[ $CUTFIL = *"NTel3"* ]]; then
                                sed -i "s/NImages>1/NImages>2/" "$MVADIR"/BDT.runparameter
                            fi
                            ./IRF.trainTMVAforGammaHadronSeparation.sh \
                                         "${TRAINDIR}" \
                                         "$MVADIR"/BDT.runparameter \
                                         "${MVADIR}" BDT ${SIMTYPE} ${VX} "${ATM}"
                         # Cut optimization
                         elif [[ $IRFTYPE == "OPTIMIZETMVA" ]]; then
                             echo "OPTIMIZE TMVA $C"
                             ./IRF.optimizeTMVAforGammaHadronSeparation.sh \
                                 "${BDTDIR}/BackgroundRates/${VX:0:2}" \
                                 "${C/PointSource-/}" \
                                 ${SIMTYPE} ${VX} "${ATM}"
                         fi
                    done
                done
            done
            continue
       fi
       #################################################
       # zenith angle dependent analysis
       for ZA in ${ZENITH_ANGLES[@]}; do
            ######################
            # train MVA for angular resolution
            if [[ $IRFTYPE == "TRAINMVANGRES" ]]; then
               FIXEDWOBBLE="0.25 0.5 0.75 1.0 1.5"
               if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
                   FIXEDNSB="150 200 250"
                   FIXEDWOBBLE="0.25 0.5 0.75 1.00 1.50"
               elif [[ ${SIMTYPE} = "CARE_RedHV" ]]; then
                   FIXEDWOBBLE="0.5"
                   FIXEDNSB="300 600 900"
               elif [[ ${SIMTYPE} = "CARE_RedHV_"* ]]; then
                   FIXEDNSB="300 600 900"
               elif [[ ${SIMTYPE} = "CARE_UV"* ]]; then
                   FIXEDWOBBLE="0.5"
                   FIXEDNSB="160 200 300"
               elif [[ ${SIMTYPE:0:4} = "CARE" ]]; then
                   FIXEDNSB="160 200 250"
               fi
               $(dirname "$0")/IRF.trainTMVAforAngularReconstruction.sh \
                   $VX $ATM $ZA "$FIXEDWOBBLE" "$FIXEDNSB" 0 \
                   $SIMTYPE $ANATYPE $UUID
               continue
            fi
            for NOISE in ${NSB_LEVELS[@]}; do
                #######################
                # analyse tables and generate effective areas
                if [[ $IRFTYPE == "ANATABLESEFFAREAS" ]]; then
                   for ID in $RECID; do
                      TFIL="${TABLECOM}"
                      # note: the IDs dependent on what is written in EVNDISP.reconstruction.runparameter
                      TFILID=$TFIL$ANATYPE
                      CUTLIST=$(read_cutlist "$CUTSLISTFILE")
                      echo "CUTLIST $CUTLIST"
                      for CUTS in ${CUTLIST[@]}; do
                         echo "Generate effective areas $CUTS"
                         $(dirname "$0")/IRF.generate_mscw_effective_area_parts.sh \
                             $TFILID $CUTS $VX $ATM $ZA \
                             "${WOBBLE_OFFSETS}" "${NOISE}" \
                             $ID $SIMTYPE $ANATYPE \
                             $DISPBDT $UUID
                      done
                   done
                   continue
                fi
                for WOBBLE in ${WOBBLE_OFFSETS[@]}; do
                    echo "Now processing epoch $VX, atmo $ATM, zenith angle $ZA, wobble $WOBBLE, noise level $NOISE"
                    ######################
                    # run simulations through evndisp
                    if [[ $IRFTYPE == "EVNDISP" ]] || [[ $IRFTYPE == "MVAEVNDISP" ]] || [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                       if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
                          SIMDIR=${VERITAS_DATA_DIR}/simulations/"$VX"_FLWO/grisu/ATM"$ATM"
                       elif [[ ${SIMTYPE:0:13} = "CARE_June2020" ]]; then
                          SIMDIR=${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations/Atmosphere${ATM}/Zd${ZA}/
                       elif [[ ${SIMTYPE} == "CARE_RedHV_Feb2024" ]]; then
                          SIMDIR=${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations_redHV/Atmosphere${ATM}/Zd${ZA}/
                       elif [[ ${SIMTYPE} == "CARE_202404" ]]; then
                          SIMDIR=${VERITAS_DATA_DIR}/simulations/NSOffsetSimulations_202404/Atmosphere${ATM}/Zd${ZA}/
                       elif [[ ${SIMTYPE:0:12} = "CARE_Jan2024" ]]; then
                          OBSTYPE=${SIMTYPE:13}
                          SIMDIR="${VERITAS_USER_DATA_DIR}/simpipe_test/data/ATM${ATM}/Zd${ZA}/MERGEVBF_${OBSTYPE}/"
                       fi
                       if [[ $IRFTYPE == "EVNDISP" ]]; then
                           $(dirname "$0")/IRF.evndisp_MC.sh \
                               $SIMDIR $VX $ATM $ZA $WOBBLE $NOISE \
                               $SIMTYPE $ACUTS 1 $ANATYPE $UUID
                       elif [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                           $(dirname "$0")/IRF.compress_evndisp_MC.sh \
                               $SIMDIR $VX $ATM $ZA $WOBBLE $NOISE \
                               $SIMTYPE $ANATYPE $UUID
                       fi
                    ######################
                    # make tables
                    elif [[ $IRFTYPE == "MAKETABLES" ]]; then
                        for ID in $RECID; do
                           $(dirname "$0")/IRF.generate_lookup_table_parts.sh \
                               $VX $ATM $ZA $WOBBLE $NOISE \
                               $ID $SIMTYPE $ANATYPE $UUID
                        done #recID
                    ######################
                    # analyse table files
                    elif [[ $IRFTYPE == "ANALYSETABLES" ]]; then
                        for ID in $RECID; do
                            TFIL="${TABLECOM}"
                            # note: the IDs dependent on what is written in EVNDISP.reconstruction.runparameter
                            TFILID=$TFIL$ANATYPE
                            $(dirname "$0")/IRF.mscw_energy_MC.sh \
                                $TFILID $VX $ATM $ZA $WOBBLE $NOISE \
                                $ID $SIMTYPE $ANATYPE $DISPBDT $UUID
			            done #recID
                    ######################
                    # analyse effective areas
                    elif [[ $IRFTYPE == "EFFECTIVEAREAS" ]] || [[ $IRFTYPE == "PRESELECTEFFECTIVEAREAS" ]]; then
                        CUTLIST=$(read_cutlist "$CUTSLISTFILE")
                        echo "CUTLIST: $CUTLIST"
                        for ID in ${RECID}; do
                            for CUTS in ${CUTLIST[@]}; do
                               echo "calculate effective areas $CUTS (ID $ID)"
                               $(dirname "$0")/IRF.generate_effective_area_parts.sh \
                                   $CUTS $VX $ATM $ZA $WOBBLE $NOISE \
                                   $ID $SIMTYPE $ANATYPE \
                                   $DISPBDT $UUID
                            done # cuts
                        done #recID
                    fi
                done #wobble
            done #noise
        done #ZA
    done #ATM
done  #VX

# Go back to the original user directory.
cd $olddir
echo "UUID for this processing batch: ${UUID}"
exit
