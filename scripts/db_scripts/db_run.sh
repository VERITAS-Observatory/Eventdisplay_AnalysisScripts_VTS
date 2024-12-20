#!/bin/bash
#
# extract information from VERITAS database required
# for evndisp analysis
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_run.sh : read data required for evndisp analysis from VTS database

db_run.sh <run> [force overwrite=1]

or

db_run.sh <run>

examples:

   ./db_run.sh 64080

"
exit
fi

RUN=$1
OVERWRITE="0"
[[ "$2" ]] && OVERWRITE=$2 || OVERWRITE=0
NTEL="4"

DBDIR="${VERITAS_DATA_DIR%/}/shared/DBTEXT/"
mkdir -p ${DBDIR}

getDBTextFileDirectory()
{
    TRUN="$1"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${DBDIR%/}/${TRUN:0:1}/${TRUN}"
    else
        ODIR="${DBDIR%/}/${TRUN:0:2}/${TRUN}"
    fi
    echo ${ODIR}
}

get_file_status()
{
    TRUN="$1"
    TFIL="$2"

    if [[ ${OVERWRITE} == 1 ]]; then
        echo "0"
    elif [[ -e ${TFIL} ]]; then
        echo "2"
    else
        TARF="$(getDBTextFileDirectory ${RRUN}).tar.gz"
        if [[ -e ${TARF} ]]; then
            FFIL="${RRUN}/$(basename ${TFIL})"
            CFIL=$(tar -tzf ${TARF} ${FFIL} 2>/dev/null)
            if [[ "${CFIL}" == "${FFIL}" ]]; then
                echo "1"
            else
                echo "0"
            fi
         else
             echo "0"
         fi
     fi
}

get_start_time()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.runinfo"
    if [[ "$1" == "DB" ]]; then
        field_name="db_start_time"
    else
        field_name="data_start_time"
    fi
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ ));
            do
                if [[ ${a[$j]} == "$field_name" ]]; then
                    start_time_index=$j
                    break;
                fi
            done
        fi
        start_time="${a[$start_time_index]}"
    done < ${OFIL}
    echo "${start_time}"
}

get_end_time()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.runinfo"
    if [[ "$1" == "DB" ]]; then
        field_name="db_end_time"
    else
        field_name="data_end_time"
    fi
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ ));
            do
                if [[ ${a[$j]} == "$field_name" ]]; then
                    end_time_index=$j
                    break;
                fi
            done
        fi
        end_time="${a[$end_time_index]}"
    done < ${OFIL}
    # add 1 minute to end time to be save
    end_time=$(date -d "${end_time} 1 minutes" +'%Y-%m-%d %H:%M:%S')
    echo "${end_time}"
}

get_laser_run()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.laserrun"
    LASERRUN=""
    while IFS="|" read -ra a; do
        if [[ ${a[0]} != "run_id" ]]; then
            LASERRUN="${LASERRUN} ${a[0]}"
        fi
    done < ${OFIL}
    echo ${LASERRUN}
}

get_excluded_telescopes()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.laserrun"
    excluded_telescopes=""
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ ));
            do
                if [[ ${a[$j]} == "excluded_telescopes" ]]; then
                    excluded_telescopes_index=$j
                    break
                fi
            done
        fi
        if [[ ${a[0]} == "$1" ]]; then
            excluded_telescopes=${a[$excluded_telescopes_index]}
        fi
    done < ${OFIL}
    echo ${excluded_telescopes}
}


hasbitset()
{
    local num=$1
    local bit=$2
    bitset="0"

    if (( num & 2**(bit-1) )); then
        bitset="1"
    else
        bitset="0"
    fi
    echo $bitset
}

get_source_id()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.runinfo"
    if [[ ! -e ${OFIL} ]] && [[ -e $(getDBTextFileDirectory ${RUN}).tar.gz ]]; then
        OFIL=$(tar -xzf $(getDBTextFileDirectory ${RUN}).tar.gz ${RUN}/${RUN}.runinfo -O)
    else
        OFIL=$(cat $OFIL)
    fi
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ ));
            do
                if [[ ${a[$j]} == "source_id" ]]; then
                    source_index=$j
                    break
                fi
            done
        fi
        source_id="${a[$source_index]}"
    done <<< "$OFIL"
    echo ${source_id}
}

# generic function to read call scripts reading from DB
# parameter ${1} should be the tool
read_run_from_DB()
{
    TTOOL=${1}
    [[ "$2" ]] && RRUN=$2 || RRUN=${RUN}
    [[ "$3" ]] && TELID=$3 || TELID=""
    [[ "$4" ]] && USETIME=$4 || USETIME="0"
    if [[ -z ${TELID} ]]; then
        OFIL="$(getDBTextFileDirectory ${RRUN})/${RRUN}.${TTOOL}"
    else
        OFIL="$(getDBTextFileDirectory ${RRUN})/${RRUN}.${TTOOL}_TEL${TELID}"
    fi
    FILESTATUS="$(get_file_status ${RRUN} ${OFIL})"
    if [[ ${FILESTATUS} == 0 ]]; then
        mkdir -p "$(getDBTextFileDirectory ${RRUN})"
        rm -f ${OFIL}
        if [[ $USETIME -eq "0" ]]; then
            cmd="./db_${TTOOL}.sh ${RRUN} ${TELID}"
        else
            cmd="./db_${TTOOL}.sh \"$(get_start_time)\" \"$(get_end_time)\" ${TELID}"
        fi
        eval "$cmd" > ${OFIL}
        echo "${TTOOL} file (written): ${OFIL}"
    elif [[ ${FILESTATUS} == 1 ]]; then
        echo "${TTOOL} file (in tar package): ${OFIL}"
    else
        echo "${TTOOL} file (found): ${OFIL}"
    fi
}

read_laser_run_and_dqm()
{
    read_run_from_DB laserrun
    LASERRUN=($(get_laser_run))
    for L in "${LASERRUN[@]}"
    do
        if [[ -n ${L} ]]; then
            read_run_from_DB rundqm ${L}
        fi
    done
}

read_target()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.target"
    source_id=$(get_source_id)
    FILESTATUS="$(get_file_status ${RUN} ${OFIL})"
    if [[ ${FILESTATUS} == 0 ]]; then
        ./db_target.sh "${source_id}" > ${OFIL}
        echo "target file (written): ${OFIL}"
    elif [[ ${FILESTATUS} == 1 ]]; then
        echo "target file (in tar package): ${OFIL}"
    else
        echo "target file (found): ${OFIL}"
    fi
}

read_camera_rotation()
{
    OFIL="$(getDBTextFileDirectory ${RUN})/${RUN}.camerarotation"
    read_run_from_DB camerarotation ${RUN} "" 1
}

read_pixel_data()
{
    read_run_from_DB L1_TriggerInfo

    for (( j=0; j<${NTEL}; j++ ));
    do
        read_run_from_DB FADCsettings ${RUN} $j 1
        read_run_from_DB HVsettings ${RUN} $j 1
    done
}

read_laser_calibration()
{
    LASERRUN=($(get_laser_run))
    for L in "${LASERRUN[@]}"
    do
        excluded_telescopes=$(get_excluded_telescopes ${L})
        for (( j=1; j<=${NTEL}; j++ ));
        do
            bittest=$(hasbitset $excluded_telescopes $j)
            if [[ $bittest == "1" ]] && [[ $excluded_telescopes != "0" ]]; then
                continue
            fi
            read_run_from_DB gain ${L} ${j}
            read_run_from_DB toffset ${L} ${j}
        done
    done
}

read_pointing()
{
    for (( j=0; j<${NTEL}; j++ ));
    do
        read_run_from_DB VPM ${RUN} $j 1
        read_run_from_DB rawpointing ${RUN} $j 1
    done
}

read_run_from_DB runinfo
read_run_from_DB rundqm
# don't test and read if tar file exists
# (implementation of testing missing)
if [[ ! -e $(getDBTextFileDirectory ${RUN}).tar.gz ]] || [[ ${OVERWRITE} == "1" ]]; then
    read_laser_run_and_dqm
    read_laser_calibration
fi
read_target
read_camera_rotation
read_pixel_data
read_pointing
read_run_from_DB lidar ${RUN} "" 1
read_run_from_DB L3 ${RUN} "" 1
read_run_from_DB weather ${RUN} "" 1
read_run_from_DB fir ${RUN} "" 1
