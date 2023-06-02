#!/bin/bash
# Update a lase files for very early V4 runs
# Some of these runs have no entries for the
# laser file in the database
# Loggen uses a lit based on date for the laser
# files

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
./db_update_old_laser_files.sh <run number> <laser run list> [calibdir]

<laser run list> is a file with the following rows:
e.g. 20070113 33341

[calibdir] - calibration directory to copy gain and toffsets
"
exit
fi

[[ "$3" ]] && CALIBDIR=$3 || CALIBDIR="NOTSET"

# DQM files are read this directory
DBTEXTDIRECTORY="$VERITAS_DATA_DIR/DBTEXT"

get_db_text_tar_file()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo "${DBTEXTDIRECTORY}/${SRUN}/${RRUN}.tar.gz"
}

get_date()
{
    RUNINFOSTRING=$(tar -axf ${2} ${1}/${1}.runinfo -O)
    DATE=$(echo "${RUNINFOSTRING}" | cut -d '|' -f 5 | grep -v db_start_time | tr -d '-')
    echo "${DATE:0:8}"
     
}

fill_laser_run()
{
    mkdir -p tmp_update_laser_run
    cd tmp_update_laser_run
    cp ${2} .
    TFILE=$(basename ${2})
    tar -xzf ${TFILE}
    rm -f ${TFILE}
    echo "Updating laser file ${1}/${1}.laserrun"
    echo "run_id|excluded_telescopes|config_mask" >> ${1}/${1}.laserrun
    echo "${3}|0|15" >> ${1}/${1}.laserrun
    cd ..
}

fill_gain_or_toff()
{
    LRUN=${1}
    LRUN="33725"
    mkdir -p tmp_update_laser_run
    cd tmp_update_laser_run
    mkdir -p ${LRUN}
    if [[ -e ${CALIBDIR}/Tel_${2}/${LRUN}.${3/set/} ]]; then
        cp -v ${CALIBDIR}/Tel_${2}/${LRUN}.${3/set/} ${LRUN}/${LRUN}_${3}_${2}
        sed -i "1s/^/channel_id|${3}_mean|${3}_var\n/" ${LRUN}/${LRUN}_${3}_${2}
        sed -i "s/ /|/g" ${LRUN}/${LRUN}_${3}_${2}
    else
        echo "No calibration found for ${LRUN} ${2}"
        echo "${CALIBDIR}/Tel_${2}/${LRUN}.${3}"
    fi
    cd ..
}    

DBTEXTFILE=$(get_db_text_tar_file ${1})
if [[ ! -e ${DBTEXTFILE} ]]; then
    echo "Error: db tar file nout found: ${DBTEXTFILE}"
    exit
fi

echo "checking for laser runs for run ${1}"
LASERSTRING=$(tar -axf ${DBTEXTFILE} ${1}/${1}.laserrun -O)
if [ !  -z "${LASERSTRING}" ]; then
    OBSDATE=$(get_date ${1} ${DBTEXTFILE})
    echo "   Observation date is: ${OBSDATE} found in  ${2}"
    LASERRUN=$(grep ${OBSDATE} ${2})
    if [ -n "${LASERRUN}" ]; then
        echo "   FOUND ${LASERRUN} ${OBSDATE}"
        # fill_laser_run ${1} ${DBTEXTFILE} $(echo "$LASERRUN" | cut -d ' ' -f 2)
        if [ ${CALIBDIR} != "NOTSET" ]; then
            for T in 1 2 3 4
            do
                fill_gain_or_toff $(echo "$LASERRUN" | cut -d ' ' -f 2) ${T} gain
                fill_gain_or_toff $(echo "$LASERRUN" | cut -d ' ' -f 2) ${T} toffset
            done
        fi
    else
        echo "   NOT FOUND ${OBSDATE}"
    fi
else
    echo "  LASERSTRING exists: ${LASERSTRING}"
fi
