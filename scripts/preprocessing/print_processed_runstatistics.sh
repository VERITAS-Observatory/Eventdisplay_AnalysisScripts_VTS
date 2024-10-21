#!/bin/bash
# Print processed run statistics for the different
# stages of Eventdisplay

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
Print processed run statistics

./print_processed_runstatistics.sh <preprocessed directory> <directory with runlists for all good runs>


"
exit
fi

FILEDIR="${1}"
GOODFDIR="${2}"

echo "| Epoch | Stage | Total number | Processed |"
echo "| -------- | -------- | -------- | -------- |"

count_files()
{
    LL=0

    if [[ $1 == "V6" ]]; then
        LL=$(find ${2} -name "*${3}" ! -name "*IPR.root" -exec basename {} "$3" \; | awk -F '-' '{if ($1 > 63372) print $0}' | wc -l) 
    elif [[ $1 == "V4" ]]; then
        LL=$(find ${2} -name "*${3}" ! -name "*IPR.root" -exec basename {} "$3" \; | awk -F '-' '{if ($1 > 1000 && $1 < 46642) print $1}' | wc -l) 
    elif [[ $1 == "V5" ]]; then
        LL=$(find ${2} -name "*${3}" ! -name "*IPR.root" -exec basename {} "$3" \; | awk -F '-' '{if ($1 > 46641 && $1 < 63373) print $0}' | wc -l) 
    fi
    echo "$LL"
}

for E in _V6 _V5 _V4
do
    GLIST="$GOODFDIR/runlist${E}.dat"
    GOODRUNS=$(cat ${GLIST} | wc -l)

    for S in evndisp mscw
    do
        LL="0"
        if [[ $S == "evndisp" ]]; then
            LL=$(count_files ${E:1} ${1}/${S}/ ".root")
        elif [[ $S == "mscw" ]]; then   
            LL=$(count_files ${E:1} ${1}/${S}/ ".mscw.root")
        fi

        echo "| ${E:1} | $S | ${GOODRUNS} | $LL |"
    done
done
