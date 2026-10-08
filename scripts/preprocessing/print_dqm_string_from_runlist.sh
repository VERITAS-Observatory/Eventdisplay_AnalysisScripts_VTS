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

get_db_text_tar_file()
{
    local RRUN=${1}
    local SRUN
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    printf '%s/%s/%s.tar.gz\n' "${DBTEXTDIRECTORY}" "${SRUN}" "${RRUN}"
}

read_db_text_file()
{
    local RRUN=${1}
    local DBFILE=${2}
    local DBRUNFIL
    DBRUNFIL=$(get_db_text_tar_file "${RRUN}")

    [[ -f ${DBRUNFIL} ]] || return 1
    tar -xOzf "${DBRUNFIL}" "${RRUN}/${RRUN}.${DBFILE}" 2>/dev/null
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
          # Time-cut masks may contain decimal values (for example
          # 720.0/840.0), which Bash arithmetic cannot evaluate directly.
          diff=$(awk -v denom="$denom" -v num="$num" 'BEGIN { print denom - num }')
          echo "TIMECUT * $RUN $num $diff 0"
      fi
    done
}

RUNS=$(cat "$RUNLIST")

for R in $RUNS
do
        if RDQM=$(read_db_text_file "${R}" rundqm); then
            RSTATUS=$(printf '%s\n' "${RDQM}" | cut -d '|' -f 3 | grep -v status)
            RCUTMASK=$(printf '%s\n' "${RDQM}" | cut -d '|' -f 7 | grep -v status)
            RCATEGORY=$(printf '%s\n' "${RDQM}" | cut -d '|' -f 2 | grep -v data_category)
        else
            RSTATUS="NODQMFILE"
            RCUTMASK="NULL"
            RCATEGORY="NOCATEGORY"
        fi
        if RINF=$(read_db_text_file "${R}" runinfo); then
            RLENGTH=$(printf '%s\n' "${RINF}" | cut -d '|' -f 9 | grep -v duration)
            RWEATHER=$(printf '%s\n' "${RINF}" | cut -d '|' -f 10 | grep -v weather)
            RTARGET=$(printf '%s\n' "${RINF}" | cut -d '|' -f 20 | grep -v source_id)
            RTYPE=$(printf '%s\n' "${RINF}" | cut -d '|' -f 2 | grep -v run_type)
        else
            RLENGTH="NORUNINFOFILE"
            RWEATHER="NULL"
            RTARGET="NOTARGET"
            RTYPE="NOTYPE"
        fi
        echo "$R $RSTATUS $RCUTMASK LENGTH: $RLENGTH WEATHER-$RWEATHER $RCATEGORY $RTARGET $RTYPE"
        anasum_time_cut "$R" "$RCUTMASK"

done
