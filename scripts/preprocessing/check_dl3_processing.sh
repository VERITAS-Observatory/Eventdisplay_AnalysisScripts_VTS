#!/bin/bash
# Check the number of files for DL3 processing

NFIL=$(find ${1}/point-like -name "*.fits.gz" | wc -l)

if [[ ${VERITAS_ANALYSIS_TYPE:0:2} == "AP" ]]; then
    CUTS="moderate2tel soft2tel hard2tel hard3tel"
else
    CUTS="supersoftNN2tel"
fi

TYPES="dl3_pointlike-all dl3_pointlike dl3_fullenclosure-all-events dl3_fullenclosure"

for T in $TYPES; do
    for C in $CUTS; do
        echo "Checking $T $C in ${1}/${T}_${C}"
        NFIL=$(find ${1}/${T}_${C} -name "*.fits.gz" | wc -l)
        NLOG=$(find ${1}/${T}_${C} -name "*.log" | wc -l)
        echo "Number of files: $NFIL $NLOG"
    done
done
