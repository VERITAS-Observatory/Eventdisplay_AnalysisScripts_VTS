#!/bin/bash
# Print DQM information in one single line
# for each run using DBText files
#
if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
Print DQM information in one single line for runs from a run list.

./print_dqm_string_from_runlist.sh < runlist >

"
exit
fi

RUNLIST=${1}

DBTEXTDIRECTORY="$VERITAS_DATA_DIR/shared/DBTEXT"

unpack_db_textdirectory()
{
    RRUN=${1}
    TMP_DBTEXTDIRECTORY=${2}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    DBRUNFIL="${DBTEXTDIRECTORY}/${SRUN}/${RRUN}.tar.gz"
    if [[ -e ${DBRUNFIL} ]]; then
        mkdir -p ${TMP_DBTEXTDIRECTORY}/
        tar -xzf ${DBRUNFIL} -C ${TMP_DBTEXTDIRECTORY}/
    fi
    echo "${TMP_DBTEXTDIRECTORY}/${RRUN}/"
}

anasum_time_cut()
{
    RUN="$1"
    MASK="$2"
    if [[ "$MASK" == *NULL* ]]; then
        return
    fi
    echo "RUN $RUN TIME CUT $MASK"
    data=$(echo "$MASK" | sed 's/.*time_cut_mask[^0-9]*//')
    echo "$data" | tr ',' '\n' | while IFS='/' read -r num denom; do
      if [[ -n "$num" && -n "$denom" ]]; then
          diff=$((denom - num))
          echo "TIMECUT * $RUN $num $diff 0"
      fi
    done
}

for E in ""
do
    RUNS=$(cat $RUNLIST)

    for R in $RUNS
    do
        DBTEXTDIR=$(unpack_db_textdirectory ${R} ./tmp_dbtext/)
        RDQM="./tmp_dbtext/${R}/${R}.rundqm"
        if [[ -e ${RDQM} ]]; then
            RSTATUS=$(cut -d '|' -f 3 ${RDQM} | grep -v status)
            RCUTMASK=$(cut -d '|' -f 7 ${RDQM} | grep -v status)
            RCATEGORY=$(cut -d '|' -f 2 ${RDQM} | grep -v data_category)
        else
            RSTATUS="NODQMFILE"
            RCUTMASK="NULL"
            RCATEGORY="NOCATEGORY"
        fi
        RINF="./tmp_dbtext/${R}/${R}.runinfo"
        if [[ -e ${RINF} ]]; then
            RLENGTH=$(cut -d '|' -f 9 ${RINF} | grep -v duration)
            RWEATHER=$(cut -d '|' -f 10 ${RINF} | grep -v weather)
            RTARGET=$(cut -d '|' -f 20 ${RINF} | grep -v source_id)
            RTYPE=$(cut -d '|' -f 2 ${RINF} | grep -v run_type)
        else
            RLENGTH="NORUNINFOFILE"
            RWEATHER="NULL"
            RTARGET="NOTARGET"
            RTYPE="NOTYPE"
        fi
        echo $R $RSTATUS $RCUTMASK LENGTH: $RLENGTH WEATHER-$RWEATHER $RCATEGORY $RTARGET $RTYPE
        anasum_time_cut $R "$RCUTMASK"

    done
done
