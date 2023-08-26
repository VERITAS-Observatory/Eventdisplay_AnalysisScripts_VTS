#!/bin/bash
# Move Eventdisplay data products from all stages
# into an runs_with_issues directory.
# runs are given in a run list
if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
Archive runs into runs_with_issues directory.
Apply this to all data products.

./archive_error_files.sh <run list>

"
exit
fi

RUNLIST=${1}

EDVERSION=`$EVNDISPSYS/bin/evndisp --version | tr -d .`
# list of data products
DP="evndisp mscw anasum_moderate2tel"
# archive directory
for D in $DP
do
    DDIR=${VERITAS_DATA_DIR}/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/runs_with_issues/${D}
    for N in 3 4 5 6 7 8 9 10
    do
        mkdir -p -v ${DDIR}/$N
    done
done

get_suffix()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo ${SRUN}
}

FF=$(cat ${1})

for D in $DP
do
    DDIR="$VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/${D}/"
    ODIR="${VERITAS_DATA_DIR}/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/runs_with_issues/${D}/"

    for F in $FF
    do
        mv -v ${DDIR}/$(get_suffix $F)/${F}* ${ODIR}/$(get_suffix $F)/
    done
done
