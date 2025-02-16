#!/bin/bash
# Run anasum or V2DL3 over all standard cuts
#
#

if [[ ${VERITAS_ANALYSIS_TYPE:0:2} == "AP" ]]; then
    CUTS="moderate2tel soft2tel hard2tel hard3tel"
else
    CUTS="supersoftNN2tel"
fi

if [ $# -lt 2 ]; then
echo "
./ANALYSIS.anasum_allcuts.sh <run list> < ANASUM / V2DL3 / PRECUTS > [major epoch]

    Run anasum or V2LD3 applying standard cuts.

    ANALYSIS TYPE: ${VERITAS_ANALYSIS_TYPE:0:2}
    CUTS: $CUTS

"
exit
fi

RUNL=${1}
RUNTYPE=${2}
EPOCH="${3:-V6}"
IGNORETYPE="IGNOREACCEPTANCE"
# set this to zero to force reprocessing
SKIPIFPROCESSED="0"
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFMINORVERSION)
EDMAJORVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

# anasum file are writing into this directory
TMPDIR="$VERITAS_DATA_DIR/tmp/${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/"
# BDT preparation cuts
if [[ ${RUNTYPE} == "PRECUTS" ]]; then
    if [[ ${VERITAS_ANALYSIS_TYPE:0:2} == "AP" ]]; then
        CUTS="NTel2ModeratePre NTel2SoftPre NTel2HardPre NTel3HardPre"
    else
        CUTS="NTel2SuperSoftPre"
    fi
    echo "BDT preparation cuts: $CUTS"
    IGNORETYPE="IGNOREIRF"
    SKIPIFPROCESSED="0"
    TMPDIR="$VERITAS_IRFPRODUCTION_DIR/$EDMAJORVERSION/${VERITAS_ANALYSIS_TYPE:0:2}/BDTtraining/BackgroundRates/${EPOCH}"
fi

PREDIR="$VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/mscw/"
echo $PREDIR
echo "TMP $TMPDIR"

# temporary file for output
TMPLOG="$(pwd)/anasum.submit.$(uuidgen).tmp.txt"
rm -f ${TMPLOG}

for C in $CUTS
do
    if [[ $RUNTYPE == "ANASUM" ]] || [[ $RUNTYPE == "PRECUTS" ]]; then
        CDIR="anasum_${C}"
        if  [[ $RUNTYPE == "PRECUTS" ]]; then
            CDIR=$(echo "$CDIR" | sed -E 's/anasum_(NTel[23])([A-Za-z]+)Pre/\1-\2/')
        fi
        echo $CDIR
        mkdir -p "$TMPDIR/{CDIR}"
        ./ANALYSIS.anasum_parallel_from_runlist.sh ${RUNL} \
            "$TMPDIR/${CDIR}" \
            ${C} \
            ${IGNORETYPE} \
            $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/ANASUM.runparameter \
            $PREDIR $SKIPIFPROCESSED | tee -a ${TMPLOG}
    elif [[ $RUNTYPE == "V2DL3" ]]; then
        mkdir -p "$TMPDIR/v2dl3_${C}"
         ./ANALYSIS.v2dl3.sh ${RUNL} \
             "$TMPDIR/v2dl3_${C}" \
             ${C} | tee -a ${TMPLOG}
    else
        echo "Error: unknown run type $RUNTYPE (allowed: ANASUM, V2DL3, or PRECUTS)"
        exit
    fi
done

echo
echo "===================================================================="
echo "JOB SUBMISSION"
echo "===================================================================="
grep -A 1 "Job submission using HTCondor" ${TMPLOG} | sort -r -u
rm -f ${TMPLOG}
