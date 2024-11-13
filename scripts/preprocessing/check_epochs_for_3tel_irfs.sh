#!/bin/bash
# Read mscw log files and derive epoch lists for summer / winter

if [ ! -n "$1" ]; then
echo "
./check_epochs_for_3tel_irfs.sh <run list>
"
exit
fi

RUNLIST="${1}"
RUNS=$(cat $RUNLIST)

DDIR="$VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/mscw/"

for ID in 2 3 4 5; do
    rm -f "IRF_EPOCHS_SUMMER_ID${ID}"
    rm -f "IRF_EPOCHS_WINTER_ID${ID}"
    touch "IRF_EPOCHS_SUMMER_ID${ID}"
    touch "IRF_EPOCHS_WINTER_ID${ID}"
done

# directory schema
getNumberedDirectory()
{
    TRUN="$1"
    IDIR="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        NDIR="${IDIR}/${TRUN:0:1}/"
    else
        NDIR="${IDIR}/${TRUN:0:2}/"
    fi
    echo ${NDIR}
}

for R in $RUNS; do
    LOGDIR=$(getNumberedDirectory $R ${DDIR})
    LOGFIL="${LOGDIR}/${R}.mscw.log"
    if [[ -e $LOGFIL ]]; then
        TELSTRING=$(grep "Mean pedvar per telescope" ${LOGFIL})
        pedvars=($(echo "$TELSTRING" | awk '{for(i=5;i<=NF;i++) print $i}'))
        T="T"
        for i in "${!pedvars[@]}"; do
            telescope=$((i + 1))
            if [[ "${pedvars[i]}" != "0" ]]; then
                T="${T}${telescope}"
            fi
        done
        if [[ $T != "T1234" ]]; then
            EPOCHSTRING=$(grep "Evaluating instrument" ${LOGFIL})
            EPOCH=$(echo "$EPOCHSTRING" | sed -n 's/.*is: \([^)]*\)).*/\1/p')
            ATMOSTRING=$(grep "Evaluating atmosphere ID" ${LOGFIL})
            ATMOID=$(echo "$ATMOSTRING" | sed -n 's/.*is: \([0-9]*\)).*/\1/p')
            if [[ $T == "T123" ]]; then
                ID=5
            elif [[ $T == "T124" ]]; then
                ID=4
            elif [[ $T == "T134" ]]; then
                ID=3
            elif [[ $T == "T234" ]]; then
                ID=2
            fi
            echo "3-TELESCOPE RUN $R TELESCOPESTRING $T $EPOCH $ATMOID $ID"
            if [[ $ATMOID == "61" ]]; then
                echo "${EPOCH}" >> "IRF_EPOCHS_WINTER_ID${ID}"
            elif [[ $ATMOID == "62" ]]; then
                echo "${EPOCH}" >> "IRF_EPOCHS_SUMMER_ID${ID}"
            fi
        fi
   else
       echo "RUN $R logfile missing" >> /dev/null
   fi
done

for ID in 2 3 4 5; do
    sort -u "IRF_EPOCHS_WINTER_ID${ID}" -o "IRF_EPOCHS_WINTER_ID${ID}"
    sort -u "IRF_EPOCHS_SUMMER_ID${ID}" -o "IRF_EPOCHS_SUMMER_ID${ID}"
done
