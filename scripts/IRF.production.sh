#!/bin/bash
# IRF production script (VERITAS)
#
# full list of epochs:
# V6_2012_2013 V6_2013_2014 V6_2014_2015 V6_2015_2016 V6_2016_2017 V6_2017_2018 V6_2018_2019 V6
#
#

if [ $# -lt 2 ]; then
# begin help message
echo "
IRF generation: produce a full set of instrument response functions (IRFs)

IRF.production.sh <sim type> <IRF type> [epoch] [atmosphere] [Rec ID] [cuts list file] [sim directory]

required parameters:

    <sim type>              original VBF file simulation type (e.g. GRISU-SW6, CARE_June2020, CARE_RedHV)
    
    <IRF type>              type of instrument response function to produce
                            (e.g. EVNDISP, MAKETABLES, COMBINETABLES,
                             (ANALYSETABLES, EFFECTIVEAREAS,)
                             ANATABLESEFFAREAS, COMBINEEFFECTIVEAREAS,
                             MVAEVNDISP, TRAINMVANGRES, EVNDISPCOMPRESS )
    
optional parameters:
    
    [epoch]                 array epoch(s) (e.g., V4, V5, V6)
                            (default: \"V4 V5 V6\")
                            (V6 epochs: \"V6_2012_2013a V6_2012_2013b V6_2013_2014a V6_2013_2014b 
			     V6_2014_2015 V6_2015_2016 V6_2016_2017 V6_2017_2018 V6_2018_2019 V6_2019_2020\")

    [atmosphere]            atmosphere model(s) (21 = winter, 22 = summer)
                            (default: \"21 22\")
                            
    [Rec ID]                reconstruction ID(s) (default: \"0 2 3 4 5\")
                            (see EVNDISP.reconstruction.runparameter)

    [cuts list file]        file containing one gamma/hadron cuts file per line
                            (default: hard-coded standard EventDisplay cuts)

    [sim directory]         directory containing simulation VBF files

    example:     ./IRF.production.sh CARE_June2020 ANALYSETABLES V6 61 0

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# We need to be in the IRF.production.sh directory so that subscripts are called
# (we call them ./).
olddir=$(pwd)
cd $(dirname "$0")

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
SIMTYPE=$1
IRFTYPE=$2
[[ "$3" ]] && EPOCH=$3 || EPOCH="V6 V5 V4"
[[ "$4" ]] && ATMOS=$4 || ATMOS="61 62"
[[ "$5" ]] && RECID=$5 || RECID="0"
[[ "$6" ]] && CUTSLISTFILE=$6 || CUTSLISTFILE=""
[[ "$7" ]] && SIMDIR=$7 || SIMDIR=""
DISPBDT=0

# evndisplay version
IRFVERSION=`$EVNDISPSYS/bin/printRunParameter --version | tr -d .| sed -e 's/[a-Z]*$//'`

# version string for aux files
AUX="auxv01"
# Analysis Type
ANATYPE="GEO"
if [[ ! -z  $VERITAS_ANALYSIS_TYPE ]]; then
   ANATYPE="$VERITAS_ANALYSIS_TYPE"
fi

# number of events per evndisp analysis
NEVENTS="-1"

# run parameter file for evndisp analysis
if [[ $IRFVERSION = "v4"* ]]; then
    ACUTS="EVNDISP.reconstruction.runparameter.v4x"
    if [[ $VERITAS_ANALYSIS_TYPE = "NN"* ]]; then
      ACUTS="EVNDISP.reconstruction.runparameter.NN.v4x"
    fi
else
    ACUTS="EVNDISP.reconstruction.runparameter"
    if [[ $VERITAS_ANALYSIS_TYPE = "NN"* ]]; then
      ACUTS="EVNDISP.reconstruction.runparameter.NN"
    fi
fi

# simulation types and definition of parameter space
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
    # GrISU simulation parameters
    ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 60 65 )
    NSB_LEVELS=( 075 100 150 200 250 325 425 550 750 1000 )
    WOBBLE_OFFSETS=( 0.5 0.00 0.25 0.75 1.00 1.25 1.50 1.75 2.00 )
    if [[ $IRFTYPE == "MVAEVNDISP" ]]; then
       NSB_LEVELS=( 200 )
       WOBBLE_OFFSETS=( 0.5 )
    fi
elif [ "${SIMTYPE}" = "CARE_June1702" ]; then
    # CARE_June1702 simulation parameters
    DDIR="$VERITAS_DATA_DIR/IRFPRODUCTION/v483/CARE_June1702"

    if [[ $ATMOS == "62" ]]; then
        ZENITH_ANGLES=( 00 30 50 )
    else
        ZENITH_ANGLES=( 00 20 30 35 40 45 50 55 )
    fi
    NSB_LEVELS=( 50 75 100 130 160 200 250 300 350 400 450 )
    WOBBLE_OFFSETS=( 0.5 )
    NEVENTS="15000000"
elif [ "${SIMTYPE}" = "CARE_RedHV" ]; then
    DDIR=${VERITAS_DATA_DIR}/simulations/V6_FLWO/CARE_June1702_RHV/
    ZENITH_ANGLES=$(ls ${DDIR}/*.zst | awk -F "_zen" '{print $2}' | awk -F "deg." '{print $1}' | sort | uniq) 
    NSB_LEVELS=$(ls ${DDIR}/*.zst | awk -F "wob_" '{print $2}' | awk -F "MHz." '{print $1}' | sort | uniq)
    WOBBLE_OFFSETS=( 0.5 ) 
elif [[ "${SIMTYPE}" = "CARE_June2020" ]]; then
    DDIR="/lustre/fs24/group/veritas/simulations/NSOffsetSimulations/Atmosphere${ATMOS}"
    ZENITH_ANGLES=$(ls ${DDIR} | awk -F "Zd" '{print $2}' | sort | uniq)
    set -- $ZENITH_ANGLES
    NSB_LEVELS=$(ls ${DDIR}/*/* | awk -F "_" '{print $8}' | awk -F "MHz" '{print $1}'| sort -u) 
    WOBBLE_OFFSETS=$(ls ${DDIR}/*/* | awk -F "_" '{print $7}' |  awk -F "wob" '{print $1}' | sort -u)
    ######################################
    # TEMPORARY
    # NSB_LEVELS=( 100 130 160 200 250 )
    # ZENITH_ANGLES=( 20 30 35 40 45 50 55 60 )
    # WOBBLE_OFFSETS=( 0.5 )
    # NSB_LEVELS=( 200 )
    # ZENITH_ANGLES=( 50 )
    # WOBBLE_OFFSETS=( 1.25 )
    # NSB_LEVELS=( 200 )
    # ZENITH_ANGLES=( 20 40 60 )
    # WOBBLE_OFFSETS=( 0.5 1.0 1.5 )
    # NSB_LEVELS=( 400 )
    # (END TEMPORARY)
    ######################################
    NEVENTS="-1"
elif [ ${SIMTYPE:0:4} = "CARE" ]; then
    # Older CARE simulation parameters
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
echo "Wobble offsets: $WOBBLE_OFFSETS"

# Set gamma/hadron cuts
if [[ $CUTSLISTFILE != "" ]]; then
    if [ ! -f $CUTSLISTFILE ]; then
        echo "Error, cuts list file not found, exiting..."
        echo $CUTSLISTFILE
        exit 1
    fi
    # read file containing list of cuts
    IFS=$'\r\n' CUTLIST=($(cat $CUTSLISTFILE))
    CUTLIST=$(IFS=$'\r\n'; cat $CUTSLISTFILE)
elif [ "${SIMTYPE}" = "CARE_RedHV" ]; then
    CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-SuperSoft.dat
             ANASUM.GammaHadron-Cut-NTel2-PointSource-Soft.dat"
elif [ "${SIMTYPE}" = "GRISU" ]; then
    CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-Moderate-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel2-PointSource-Soft-TMVA-BDT.dat 
             ANASUM.GammaHadron-Cut-NTel2-PointSource-Hard-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel3-PointSource-Hard-TMVA-BDT.dat"
else
    CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-Moderate-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel2-PointSource-Soft-TMVA-BDT.dat 
             ANASUM.GammaHadron-Cut-NTel2-PointSource-Hard-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel3-PointSource-Hard-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel2-Extended025-Moderate-TMVA-BDT.dat
             ANASUM.GammaHadron-Cut-NTel2-Extended050-Moderate-TMVA-BDT.dat"
fi
CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-TMVA-BDT-Preselection.dat
         ANASUM.GammaHadron-Cut-NTel3-PointSource-TMVA-BDT-Preselection.dat
         ANASUM.GammaHadron-Cut-NTel2-PointSource-Moderate-TMVA-Preselection.dat
         ANASUM.GammaHadron-Cut-NTel2-PointSource-Soft-TMVA-Preselection.dat
         ANASUM.GammaHadron-Cut-NTel3-PointSource-Hard-TMVA-Preselection.dat"
CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-Soft.dat
         ANASUM.GammaHadron-Cut-NTel2-PointSource-Moderate.dat"
CUTLIST="ANASUM.GammaHadron-Cut-NTel2-PointSource-Moderate.dat"
CUTLIST=`echo $CUTLIST |tr '\r' ' '`
CUTLIST=${CUTLIST//$'\n'/}

############################################################
# loop over complete parameter space and submit production
for VX in $EPOCH; do
    for ATM in $ATMOS; do
       ######################
       # set lookup table file name
       TABLECOM="table-${IRFVERSION}-${AUX}-${SIMTYPE}-ATM${ATM}-${VX}-"
       ######################
       # combine lookup tables
       if [[ $IRFTYPE == "COMBINETABLES" ]]; then
            TFIL="${TABLECOM}"
            for ID in $RECID; do
                echo "combine lookup tables"
                $(dirname "$0")/IRF.combine_lookup_table_parts.sh \
                    "${TFIL}${ANATYPE}" "$VX" "$ATM" \
                    "$ID" "$SIMTYPE" "$VERITAS_ANALYSIS_TYPE"
            done
            continue
       fi
       ######################
       # combine effective areas
       if [[ $IRFTYPE == "COMBINEEFFECTIVEAREAS" ]]; then
            for ID in $RECID; do
                for CUTS in ${CUTLIST[@]}; do
                    echo "combine effective areas $CUTS"
                   $(dirname "$0")/IRF.combine_effective_area_parts.sh \
                       "$CUTS" "$VX" "$ATM" \
                       "$ID" "$SIMTYPE" "$AUX" "$VERITAS_ANALYSIS_TYPE" \
                       "$DISPBDT"
                done # cuts
            done
            continue
       fi
       #############################################
       # MVA training
       if [[ $IRFTYPE == "TRAINTMVA" ]]
       then
            for VX in $EPOCH; do
                for C in "Moderate" "Soft" "Hard"
                do
                    echo "Training $C cuts for ${VX}"
                    MVADIR="$VERITAS_EVNDISP_AUX_DIR/GammaHadron_BDTs/${VX}/${C}/"
                    mkdir -p -v "${MVADIR}"
                    # list of background files
                    TRAINDIR="$VERITAS_USER_DATA_DIR//analysis/Results/${EDVERSION}/BDTtraining/${EDVERSION}/RecID0_${SIMTYPE}/"
                    rm -f "$MVADIR/BDTTraining.bck.list"
                    ls -1 "$TRAINDIR"/*.root > "$MVADIR/BDTTraining.bck.list"
                    NBCKF=`wc -l "$MVADIR/BDTTraining.bck.list"`
                    echo "Total number of background files for training: $NBCKF"
                    # retrieve size cut
                    CUTFIL="$VERITAS_EVNDISP_AUX_DIR"/GammaHadronCutFiles/ANASUM.GammaHadron-Cut-*${C}-TMVA-Preselection.dat
                    echo "$CUTFIL"
                    SIZECUT=`grep "* sizesecondmax" $CUTFIL | grep ${EPOCH} | awk '{print $3}' | sort -u`
                    if [ -z "$SIZECUT" ]
                    then
                        echo "No size cut found; skipping cut $C"
                        continue
                    fi
                    echo "Size cut applied: $SIZECUT"
                    cp -f "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/TMVA.BDT.runparameter "$MVADIR"/TMVA.BDT.runparameter
                    sed -i "s/TMVASIZECUT/${SIZECUT}/" "$MVADIR"/TMVA.BDT.runparameter
                    ./IRF.trainTMVAforGammaHadronSeparation.sh \
                                 "$MVADIR"/BDTTraining.bck.list \
                                 "$MVADIR"/TMVA.BDT.runparameter \
                                 "${MVADIR}" mva ${SIMTYPE} ${VX} "${ATM}" 0
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
               FIXEDWOBBLE="0.25 0.5 0.75"
               if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
                   FIXEDNSB=200
               elif [[ ${SIMTYPE:0:4} = "CARE" ]]; then
                   FIXEDNSB="160 250 250"
               fi
               $(dirname "$0")/IRF.trainTMVAforAngularReconstruction.sh \
                   $VX $ATM $ZA "$FIXEDWOBBLE" "$FIXEDNSB" 0 \
                   $SIMTYPE $VERITAS_ANALYSIS_TYPE
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
                      for CUTS in ${CUTLIST[@]}; do
                         echo "Generate effective areas $CUTS"
                         $(dirname "$0")/IRF.generate_mscw_effective_area_parts.sh \
                             $TFILID $CUTS $VX $ATM $ZA \
                             "${WOBBLE_OFFSETS}" "${NOISE}" \
                             $ID $SIMTYPE $VERITAS_ANALYSIS_TYPE \
                             $DISPBDT
                      done
                   done
                   continue
                fi
                for WOBBLE in ${WOBBLE_OFFSETS[@]}; do
                    echo "Now processing epoch $VX, atmo $ATM, zenith angle $ZA, wobble $WOBBLE, noise level $NOISE, NEVENTS $NEVENTS"
                    ######################
                    # run simulations through evndisp
                    if [[ $IRFTYPE == "EVNDISP" ]] || [[ $IRFTYPE == "MVAEVNDISP" ]] || [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                       if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
                          SIMDIR=$VERITAS_DATA_DIR/simulations/"$VX"_FLWO/grisu/ATM"$ATM"
                       elif [[ ${SIMTYPE:0:13} = "CARE_June1425" ]]; then
                          SIMDIR=$VERITAS_DATA_DIR/simulations/"${VX:0:2}"_FLWO/CARE_June1425/
                       elif [[ ${SIMTYPE:0:10} = "CARE_RedHV" ]]; then
                          SIMDIR=$VERITAS_DATA_DIR/simulations/"${VX:0:2}"_FLWO/CARE_June1702_RHV/
                       elif [[ ${SIMTYPE:0:13} = "CARE_June2020" ]]; then
                          SIMDIR=$VERITAS_DATA_DIR/simulations/NSOffsetSimulations/Atmosphere${ATM}/Zd${ZA}/
                       elif [[ ${SIMTYPE:0:4} = "CARE" ]]; then
                          SIMDIR="/lustre/fs24/group/veritas/simulations/V6_FLWO/CARE_June1702"
                       fi
                       if [[ $IRFTYPE == "EVNDISP" ]]; then
                           $(dirname "$0")/IRF.evndisp_MC.sh \
                               $SIMDIR $VX $ATM $ZA $WOBBLE $NOISE \
                               $SIMTYPE $ACUTS 1 $NEVENTS $VERITAS_ANALYSIS_TYPE
                       elif [[ $IRFTYPE == "EVNDISPCOMPRESS" ]]; then
                           $(dirname "$0")/IRF.compress_evndisp_MC.sh \
                               $SIMDIR $VX $ATM $ZA $WOBBLE $NOISE \
                               $SIMTYPE $VERITAS_ANALYSIS_TYPE
                       fi
                    ######################
                    # make tables
                    elif [[ $IRFTYPE == "MAKETABLES" ]]; then
                        for ID in $RECID; do
                           $(dirname "$0")/IRF.generate_lookup_table_parts.sh \
                               $VX $ATM $ZA $WOBBLE $NOISE \
                               $ID $SIMTYPE $VERITAS_ANALYSIS_TYPE
                        done #recID
                    ######################
                    # analyse table files
                    elif [[ $IRFTYPE == "ANALYSETABLES" ]]; then
                        for ID in $RECID; do
                            TFIL="${TABLECOM}"
                            # note: the IDs dependent on what is written in EVNDISP.reconstruction.runparameter
                            # warning: do not mix disp and geo
                            TFILID=$TFIL$ANATYPE
                            $(dirname "$0")/IRF.mscw_energy_MC.sh \
                                $TFILID $VX $ATM $ZA $WOBBLE $NOISE \
                                $ID $SIMTYPE $VERITAS_ANALYSIS_TYPE $DISPBDT
			            done #recID
                    ######################
                    # analyse effective areas
                    elif [[ $IRFTYPE == "EFFECTIVEAREAS" ]]; then
                        for ID in $RECID; do
                            for CUTS in ${CUTLIST[@]}; do
                                echo "combine effective areas $CUTS"
                               $(dirname "$0")/IRF.generate_effective_area_parts.sh \
                                   $CUTS $VX $ATM $ZA $WOBBLE $NOISE \
                                   $ID $SIMTYPE $VERITAS_ANALYSIS_TYPE \
                                   $DISPBDT
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
exit
