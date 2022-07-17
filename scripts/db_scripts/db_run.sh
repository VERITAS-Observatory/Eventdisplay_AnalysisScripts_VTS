#!/bin/bash
#
# extract all information for run-wise DB analysis

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

DBDIR="$VERITAS_USER_DATA_DIR/analysis/Results/v490/dbtext/"
DBDIR=${DBDIR}/${RUN}
mkdir -p ${DBDIR}

get_start_time()
{
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ )); 
            do
                if [[ ${a[$j]} == "db_start_time" ]]; then
                    db_start_time_index=$j
                    break;
                fi
            done
        fi
        db_start_time="${a[$db_start_time_index]}"
    done < ${DBDIR}/${RUN}.runinfo
    echo "${db_start_time}"
}

get_end_time()
{
    while IFS="|" read -ra a; do
        if [[ ${a[0]} == "run_id" ]]; then
            for (( j=0; j<${#a[@]}; j++ )); 
            do
                if [[ ${a[$j]} == "db_end_time" ]]; then
                    db_end_time_index=$j
                    break;
                fi
            done
        fi
        db_end_time="${a[$db_end_time_index]}"
    done < ${DBDIR}/${RUN}.runinfo
    echo "${db_end_time}"
}

get_laser_run()
{
    while IFS="|" read -ra a; do
        if [[ ${a[0]} != "run_id" ]]; then
            LASERRUN=${a[0]}
        fi
    done < ${DBDIR}/${RUN}.laserrun
    echo ${LASERRUN}
}

read_runinfo()
{
    if [[ ! -e ${DBDIR}/${RUN}.runinfo ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_runinfo.sh ${RUN} > ${DBDIR}/${RUN}.runinfo
    fi
    echo "runinfo file:  ${DBDIR}/${RUN}.runinfo"
}

read_rundqm()
{
    if [[ ! -e ${DBDIR}/${RUN}.rundqm ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_rundqm.sh ${RUN} > ${DBDIR}/${RUN}.rundqm
    fi
    echo "dqm file:  ${DBDIR}/${RUN}.rundqm"
}

read_laser_run_and_dqm()
{
    if [[ ! -e ${DBDIR}/${RUN}.laserrun ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_laserrun.sh ${RUN} > ${DBDIR}/${RUN}.laserrun
    fi
    echo "laser file:  ${DBDIR}/${RUN}.laserrun"

    while IFS="|" read -ra a; do
        if [[ ${a[0]} != "run_id" ]]; then
            if [[ ! -e ${DBDIR}/${RUN}.laserrun ]] || [[ ${OVERWRITE} == 1 ]]; then
                ./db_rundqm.sh ${a[0]} > ${DBDIR}/${a[0]}.rundqm
            fi
            echo "laser dqm file:  ${DBDIR}/${a[0]}.rundqm"
        fi
    done < ${DBDIR}/${RUN}.laserrun
}

read_target()
{
    if [[ ! -e ${DBDIR}/${RUN}.target ]] || [[ ${OVERWRITE} == 1 ]]; then
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
        done < ${DBDIR}/${RUN}.runinfo
        ./db_targetname.sh "${source_id}" > ${DBDIR}/${RUN}.target
    fi
    echo "target file: ${DBDIR}/${RUN}.target"
}

read_camera_rotation()
{
    if [[ ! -e ${DBDIR}/${RUN}.camerarotation ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_camerarotation.sh "$(get_start_time)" "$(get_end_time)" > ${DBDIR}/${RUN}.camerarotation
    fi
    
    echo "camera rotation file: ${DBDIR}/${RUN}.camerarotation"
}

read_pixel_data()
{
    if [[ ! -e ${DBDIR}/${RUN}.L1_TriggerInfo ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_L1_TriggerInfo.sh ${RUN} > ${DBDIR}/${RUN}.L1_TriggerInfo
    fi
    echo "L1_TriggerInfo file: ${DBDIR}/${RUN}.L1_TriggerInfo"

    for (( j=0; j<${NTEL}; j++ ));
    do
        if [[ ! -e ${DBDIR}/${RUN}.FADCsettings_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_FADCsettings.sh "$(get_start_time)" "$(get_end_time)" ${j} > ${DBDIR}/${RUN}.FADCsettings_TEL${j}
        fi
        echo "FADC settings TEL ${j}: ${DBDIR}/${RUN}.FADCsettings_TEL${j}"
        if [[ ! -e ${DBDIR}/${RUN}.HVsettings_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_HVsettings.sh "$(get_start_time)" "$(get_end_time)" ${j} > ${DBDIR}/${RUN}.HVsettings_TEL${j}
        fi
        echo "HV settings TEL ${j}: ${DBDIR}/${RUN}.HVsettings_TEL${j}"
    done
}

read_flasher_calibration()
{
    for (( j=1; j<=${NTEL}; j++ ));
    do
        if [[ ! -e ${DBDIR}/${RUN}.gain_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_lasergain.sh ${j} > ${DBDIR}/${RUN}.gain_TEL${j}
        fi
        echo "Laser gain TEL ${j}: ${DBDIR}/${RUN}.gain_TEL${j}"
    done
}

read_runinfo
read_rundqm
read_laser_run_and_dqm
read_target
read_camera_rotation
read_pixel_data
read_flasher_calibration
