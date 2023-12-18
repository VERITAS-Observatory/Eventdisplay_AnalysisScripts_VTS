#!/bin/bash
# Run anasum or V2DL3 over all standard cuts
#
#

if [[ ${VERITAS_ANALYSIS_TYPE:0:2} == "AP" ]]; then
    CUTS="moderate2tel soft2tel hard3tel"
else
    CUTS="supersoftNN2tel"
fi


if [ $# -lt 2 ]; then
echo "
./ANALYSIS.anasum_allcuts.sh <run list> <ANASUM/V2DL3>

    Run anasum or V2LD3 applying standard cuts.

    ANALYSIS TYPE: ${VERITAS_ANALYSIS_TYPE:0:2}
    CUTS: $CUTS

"
exit
fi

RUNL=${1}
RUNTYPE=${2}

EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`

for C in $CUTS
do
    if [[ $RUNTYPE == "ANASUM" ]]; then
        mkdir -p $VERITAS_USER_DATA_DIR/analysis/Results/${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/bbb_anasum_${C}
        ./ANALYSIS.anasum_parallel_from_runlist.sh ${RUNL} \
            $VERITAS_USER_DATA_DIR/analysis/Results/${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/bbb_anasum_${C} \
            ${C} \
            IGNOREACCEPTANCE \
            $EVNDISPSYS/../EventDisplay_Release_${EDVERSION}/preprocessing/parameter_files/anasum.runparameter.dat 
    else
        CF=${C/NN/}
        mkdir -p $VERITAS_USER_DATA_DIR/analysis/Results/${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/bbb_v2dl3-${C}
         ./ANALYSIS.v2dl3.sh ${RUNL} \
             $VERITAS_USER_DATA_DIR/analysis/Results/${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/bbb_v2dl3-${C} \
             ${C}
    fi
done
