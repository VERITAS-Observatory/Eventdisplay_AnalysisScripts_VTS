#!/bin/bash
# IRF general production script (VERITAS) for large scale
# productions process all epochs
#
#

if [ $# -lt 2 ]; then
# begin help message
echo "
IRF general production for IRFs for all epochs

./IRF.generalproduction.sh <sim type> <IRF type>

required parameters:

    <sim type>              original VBF file simulation type
                            (e.g. GRISU-SW6, CARE_June2020, CARE_RedHV, CARE_UV)
    
    <IRF type>              type of instrument response function to produce
                            (e.g. EVNDISP, MAKETABLES, COMBINETABLES,
                             (ANALYSETABLES, EFFECTIVEAREAS,)
                             ANATABLESEFFAREAS, COMBINEEFFECTIVEAREAS,
                             MVAEVNDISP, TRAINTMVA, OPTIMIZETMVA, 
                             TRAINMVANGRES, EVNDISPCOMPRESS )

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# We need to be in the IRF.production.sh directory so that subscripts are called


# Parse command line arguments
SIMTYPE=$1
IRFTYPE=$2

process_irfs()
{
    EPOCHS=$(cat $4 | sort -u)
    # EPOCHS=(V6_2019_2020w V6_2020_2021w V6_2021_2022w )
    # for E in ${EPOCHS[@]};
    for E in $EPOCHS
    do
        if [[ ${E:(-1)} == "w" ]] && [[ $3 == "62" ]]; then
            continue
        fi
        if [[ ${E:(-1)} == "s" ]] && [[ $3 == "61" ]]; then
            continue
        fi
        echo $E $1 $2 $3
        ./IRF.production.sh $2 $1 $E $3
    done
}

if [[ ${SIMTYPE} == "CARE_June2020" ]]; then
    process_irfs ${IRFTYPE} ${SIMTYPE} 61 $VERITAS_EVNDISP_AUX_DIR/IRF_EPOCHS_WINTER.dat
    process_irfs ${IRFTYPE} ${SIMTYPE} 62 $VERITAS_EVNDISP_AUX_DIR/IRF_EPOCHS_SUMMER.dat
elif [[ ${SIMTYPE} == "CARE_RedHV" ]]; then
    process_irfs ${IRFTYPE} ${SIMTYPE} 61 "$VERITAS_EVNDISP_AUX_DIR/IRF_EPOC*.dat"
fi
