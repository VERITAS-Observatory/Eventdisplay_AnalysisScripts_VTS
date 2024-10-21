#!/bin/bash
# Update a laser rfiles for very early V4 runs
# Some of these runs have no entries for the
# laser file in the database
# Loggen uses a lit based on date for the laser
# files

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
./db_update_old_laser_files.sh <run number> <laser run list>

<laser run list> is a file with the following rows:
e.g. 20070113 33341

"
exit
fi

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

DBTEXTFILE=$(get_db_text_tar_file ${1})
if [[ ! -e ${DBTEXTFILE} ]]; then
    echo "Error: db tar file nout found: ${DBTEXTFILE}"
    exit
fi

echo "checking for laser runs for run ${1}"
LASERSTRING=$(tar -axf ${DBTEXTFILE} ${1}/${1}.laserrun -O)
if [ -z "${LASERSTRING}" ]; then
    OBSDATE=$(get_date ${1} ${DBTEXTFILE})
    echo "   Observation date is: ${OBSDATE} found in  ${2}"
    LASERRUN=$(grep ${OBSDATE} ${2})
    if [ -n "${LASERRUN}" ]; then
        echo "   FOUND ${LASERRUN} ${OBSDATE}"
        fill_laser_run ${1} ${DBTEXTFILE} $(echo "$LASERRUN" | cut -d ' ' -f 2)
    else
        echo "   NOT FOUND ${OBSDATE}"
    fi
else
    echo "  LASERSTRING exists: ${LASERSTRING}"
fi
