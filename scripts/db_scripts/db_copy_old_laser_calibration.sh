#!/bin/bash
# Copy gain and toff files and adapt them
# according to the DBtext standard
# Required for old V4 files with no entries
# for the laser analysis in the database

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
./db_copy_old_laser_calibration.sh <laser run number> <calibdir>

<calibdir> - calibration directory to copy gain and toffsets
"
exit
fi

LASERRUN=$1
CALIBDIR=$2

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

fill_gain_or_toff()
{
    LRUN=${1}
    if [[ -e ${CALIBDIR}/Tel_${2}/${LRUN}.${3/set/} ]]; then
        cp -v ${CALIBDIR}/Tel_${2}/${LRUN}.${3/set/} ${LRUN}/${LRUN}.${3}_TEL${2}
        sed -i "1s/^/channel_id|${3}_mean|${3}_var\n/" ${LRUN}/${LRUN}.${3}_TEL${2}
        sed -i "s/ /|/g" ${LRUN}/${LRUN}.${3}_TEL${2}
    else
        echo "No calibration found for ${LRUN} ${2}"
        echo "${CALIBDIR}/Tel_${2}/${LRUN}.${3}"
    fi
}    

DBTEXTFILE=$(get_db_text_tar_file ${1})
if [[ ! -e ${DBTEXTFILE} ]]; then
    echo "Error: db tar file not found: ${DBTEXTFILE}"
    exit
fi
mkdir -p tmp_update_laser_run
cd tmp_update_laser_run
cp -v ${DBTEXTFILE} .
tar -xzf ${DBTEXTFILE}

for T in 1 2 3 4
do
    for C in gain toffset
    do
#        if [[ ! -e ${LRUN}/${LASERRUN}.${C}_TEL${T} ]]; then
            fill_gain_or_toff $LASERRUN ${T} $C
#        else
#            echo "Calibration files $C exists for run $LASERRUN"
#        fi
    done
done

cd ..
