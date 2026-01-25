#!/bin/bash
# IRF general production script (VERITAS) for large scale
# productions process all epochs

if [ $# -lt 2 ]; then
echo "
IRF production for all epochs

./IRF.generalproduction.sh <sim type> <IRF type>

required parameters:

    <sim type>              simulation type
                            Main types: GRISU, CARE_24_20, CARE_RedHV_Feb2024, CARE_UV_2212
                            CARE_RedHV_Feb2024, CARE_202404, CARE_24_20)
                            V6 basic types: CARE_202404, CARE_RedHV_Feb2024

    <IRF type>              type of instrument response function to produce.
                            EVNDISP,
                            MAKETABLES, COMBINETABLES,
                            TRAINMVANGRES,
                            TRAINXGBANGRESBINNED, ANAXGBANGRES,
                            TRAINXGBGH, ANAXGBGH,
                            ANALYSETABLES,
                            PRESELECTEFFECTIVEAREAS, COMBINEPRESELECTEFFECTIVEAREAS,
                            TRAINTMVA, OPTIMIZETMVA,
                            ANATABLESEFFAREAS,
                            EFFECTIVEAREAS, COMBINEEFFECTIVEAREAS,
                            (EVNDISPCOMPRESS, MVAEVNDISP)

--------------------------------------------------------------------------------
"
exit
fi

SIMTYPE=$1
IRFTYPE=$2

process_irfs()
{
    EPOCHS=$(cat $4 | sort -u)
    # FIX EPOCHS="V6_2023_2023s"
    for E in $EPOCHS
    do
        if [[ $2 != "CARE_UV_2212" ]]; then
            if [[ ${E:(-1)} == "w" ]] && [[ $3 == "62" ]]; then
                continue
            fi
            if [[ ${E:(-1)} == "s" ]] && [[ $3 == "61" ]]; then
                continue
            fi
        fi
        echo $E $1 $2 $3
        if [[ "$1" == "ANALYSETABLES" ]] || [[ "$1" == "EFFECTIVEAREAS" ]] || [[ "$1" == "COMBINEEFFECTIVEAREAS" ]]; then
            for ID in 0 2 3 4 5
            do
                ./IRF.production.sh $2 $1 $E $3 $ID
            done
        else
            ./IRF.production.sh $2 $1 $E $3 0
        fi
    done
}

if [[ ${SIMTYPE} == "CARE_UV_2212" ]]; then
    process_irfs ${IRFTYPE} ${SIMTYPE} 61 $VERITAS_EVNDISP_AUX_DIR/IRF_EPOCHS_obsfilter.dat
elif [[ ${SIMTYPE} == "GRISU" ]]; then
    if [[ "$2" == "ANALYSETABLES" ]] || [[ "$2" == "EFFECTIVEAREAS" ]] || [[ "$2" == "COMBINEEFFECTIVEAREAS" ]]; then
        for ID in 0 2 3 4 5
        do
            ./IRF.production.sh GRISU ${IRFTYPE} V5 21 $ID
            ./IRF.production.sh GRISU ${IRFTYPE} V5 22 $ID
            ./IRF.production.sh GRISU ${IRFTYPE} V4 21 $ID
            ./IRF.production.sh GRISU ${IRFTYPE} V4 22 $ID
        done
    else
            ./IRF.production.sh GRISU ${IRFTYPE} V5 21 0
            ./IRF.production.sh GRISU ${IRFTYPE} V5 22 0
            ./IRF.production.sh GRISU ${IRFTYPE} V4 21 0
            ./IRF.production.sh GRISU ${IRFTYPE} V4 22 0
    fi
else
    process_irfs ${IRFTYPE} ${SIMTYPE} 61 $VERITAS_EVNDISP_AUX_DIR/IRF_EPOCHS_WINTER.dat
    process_irfs ${IRFTYPE} ${SIMTYPE} 62 $VERITAS_EVNDISP_AUX_DIR/IRF_EPOCHS_SUMMER.dat
fi
