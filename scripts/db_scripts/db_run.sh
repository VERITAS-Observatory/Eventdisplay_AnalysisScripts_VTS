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
    done < ${DBDIR}/${RUN}/${RUN}.runinfo
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
    done < ${DBDIR}/${RUN}/${RUN}.runinfo
    echo "${db_end_time}"
}

get_laser_run()
{
    while IFS="|" read -ra a; do
        if [[ ${a[0]} != "run_id" ]]; then
            LASERRUN=${a[0]}
        fi
    done < ${DBDIR}/${RUN}/${RUN}.laserrun
    echo ${LASERRUN}
}

read_runinfo()
{
    mkdir -p ${DBDIR}/${RUN}
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.runinfo ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_runinfo.sh ${RUN} > ${DBDIR}/${RUN}/${RUN}.runinfo
        echo "runinfo file (written):  ${DBDIR}/${RUN}/${RUN}.runinfo"
    else
        echo "runinfo file (found):  ${DBDIR}/${RUN}/${RUN}.runinfo"
    fi
}

read_rundqm()
{
    mkdir -p ${DBDIR}/${RUN}
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.rundqm ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_rundqm.sh ${RUN} > ${DBDIR}/${RUN}/${RUN}.rundqm
        echo "dqm file (written):  ${DBDIR}/${RUN}/${RUN}.rundqm"
    else
        echo "dqm file (found):  ${DBDIR}/${RUN}/${RUN}.rundqm"
    fi
}

read_laser_run_and_dqm()
{
    mkdir -p ${DBDIR}/${RUN}
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.laserrun ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_laserrun.sh ${RUN} > ${DBDIR}/${RUN}/${RUN}.laserrun
        echo "laser file (written):  ${DBDIR}/${RUN}/${RUN}.laserrun"
    else
        echo "laser file (found):  ${DBDIR}/${RUN}/${RUN}.laserrun"
    fi
    LASERRUN=$(get_laser_run)

    if [[ -n ${LASERRUN} ]]; then
        mkdir -p ${DBDIR}/${LASERRUN}
        if [[ ! -e ${DBDIR}/${LASERRUN}/${LASERRUN}.rundqm ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_rundqm.sh  ${LASERRUN} > ${DBDIR}/${LASERRUN}/${LASERRUN}.rundqm
            echo "dqm file (laser, written):  ${DBDIR}/${LASERRUN}/${LASERRUN}.rundqm"
        else
            echo "dqm file (laser, found):  ${DBDIR}/${LASERRUN}/${LASERRUN}.rundqm"
        fi
    fi
}

read_target()
{
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.target ]] || [[ ${OVERWRITE} == 1 ]]; then
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
        done < ${DBDIR}/${RUN}/${RUN}.runinfo
        ./db_targetname.sh "${source_id}" > ${DBDIR}/${RUN}/${RUN}.target
        echo "target file (written): ${DBDIR}/${RUN}/${RUN}.target"
    else
        echo "target file (found): ${DBDIR}/${RUN}/${RUN}.target"
    fi
}

read_camera_rotation()
{
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.camerarotation ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_camerarotation.sh "$(get_start_time)" "$(get_end_time)" > ${DBDIR}/${RUN}/${RUN}.camerarotation
        echo "camera rotation file (written): ${DBDIR}/${RUN}/${RUN}.camerarotation"
    else
        echo "camera rotation file (found): ${DBDIR}/${RUN}/${RUN}.camerarotation"
    fi
}

read_pixel_data()
{
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.L1_TriggerInfo ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_L1_TriggerInfo.sh ${RUN} > ${DBDIR}/${RUN}/${RUN}.L1_TriggerInfo
        echo "L1_TriggerInfo file (written): ${DBDIR}/${RUN}/${RUN}.L1_TriggerInfo"
    else
        echo "L1_TriggerInfo file (found): ${DBDIR}/${RUN}/${RUN}.L1_TriggerInfo"
    fi

    for (( j=0; j<${NTEL}; j++ ));
    do
        if [[ ! -e ${DBDIR}/${RUN}/${RUN}.FADCsettings_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_FADCsettings.sh "$(get_start_time)" "$(get_end_time)" ${j} > ${DBDIR}/${RUN}/${RUN}.FADCsettings_TEL${j}
            echo "FADC settings TEL ${j} (written): ${DBDIR}/${RUN}/${RUN}.FADCsettings_TEL${j}"
        else
            echo "FADC settings TEL ${j} (found): ${DBDIR}/${RUN}/${RUN}.FADCsettings_TEL${j}"
        fi
        if [[ ! -e ${DBDIR}/${RUN}/${RUN}.HVsettings_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_HVsettings.sh "$(get_start_time)" "$(get_end_time)" ${j} > ${DBDIR}/${RUN}/${RUN}.HVsettings_TEL${j}
            echo "HV settings TEL ${j} (written): ${DBDIR}/${RUN}/${RUN}.HVsettings_TEL${j}"
        else
            echo "HV settings TEL ${j} (found): ${DBDIR}/${RUN}/${RUN}.HVsettings_TEL${j}"
        fi
    done
}

read_flasher_calibration()
{
    LASERRUN=$(get_laser_run)
    for (( j=1; j<=${NTEL}; j++ ));
    do
        if [[ ! -e ${DBDIR}/${LASERRUN}/${LASERRUN}.gain_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_lasergain.sh ${LASERRUN} ${j} > ${DBDIR}/${LASERRUN}/${LASERRUN}.gain_TEL${j}
            echo "Laser gain TEL ${j} (written): ${DBDIR}/${LASERRUN}/${LASERRUN}.gain_TEL${j}"
        else
            echo "Laser gain TEL ${j} (found): ${DBDIR}/${LASERRUN}/${LASERRUN}.gain_TEL${j}"
        fi
        if [[ ! -e ${DBDIR}/${LASERRUN}/${LASERRUN}.toffset_TEL${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_lasertoffset.sh ${LASERRUN} ${j} > ${DBDIR}/${LASERRUN}/${LASERRUN}.toffset_TEL${j}
            echo "Laser toffset TEL ${j} (written): ${DBDIR}/${LASERRUN}/${LASERRUN}.toffset_TEL${j}"
        else
            echo "Laser toffset TEL ${j} (found): ${DBDIR}/${LASERRUN}/${LASERRUN}.toffset_TEL${j}"
        fi
    done
}

read_pointing()
{
    mkdir -p ${DBDIR}/${RUN}
    if [[ ! -e ${DBDIR}/${RUN}/${RUN}.pointingflag ]] || [[ ${OVERWRITE} == 1 ]]; then
        ./db_pointingflag.sh ${RUN} > ${DBDIR}/${RUN}/${RUN}.pointingflag
        echo "pointing flag file (written):  ${DBDIR}/${RUN}/${RUN}.pointingflag"
    else
        echo "pointing flag file (found):  ${DBDIR}/${RUN}/${RUN}.pointingflag"
    fi
    for (( j=0; j<${NTEL}; j++ ));
    do
        if [[ ! -e ${DBDIR}/${RUN}/${RUN}.VPM_${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_VPM.sh ${j} "$(get_start_time)" "$(get_end_time)" > ${DBDIR}/${RUN}/${RUN}.VPM_TEL${j}
            echo "VPM TEL ${j} (written): ${DBDIR}/${RUN}/${RUN}.VPM_TEL${j}"
        else
            echo "VPM TEL ${j} (found): ${DBDIR}/${RUN}/${RUN}.VPM_TEL${j}"
        fi
        if [[ ! -e ${DBDIR}/${RUN}/${RUN}.rawpointing_${j} ]] || [[ ${OVERWRITE} == 1 ]]; then
            ./db_rawpointing.sh ${j} "$(get_start_time)" "$(get_end_time)" > ${DBDIR}/${RUN}/${RUN}.rawpointing_TEL${j}
            echo "Rawpointing TEL ${j} (written): ${DBDIR}/${RUN}/${RUN}.rawpointing_TEL${j}"
        else
            echo "Rawpointing TEL ${j} (found): ${DBDIR}/${RUN}/${RUN}.rawpointing_TEL${j}"
        fi
    done
}

read_runinfo
read_rundqm
read_laser_run_and_dqm
read_target
read_camera_rotation
read_pixel_data
read_flasher_calibration
read_pointing
