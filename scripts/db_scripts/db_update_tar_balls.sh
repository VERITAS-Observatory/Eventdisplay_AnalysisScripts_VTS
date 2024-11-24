#!/bin/bash
# Update existing tar balls with DB files with new
# files.

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
db_update_tar_balls update existing tar ball with new files

./db_update_tar_balls.sh <run list> <directory with new files>

"
exit
fi

DBTEXTDIR="$VERITAS_DATA_DIR/shared/DBTEXT/"
FLIST="${1}"
NEWDIR="${2}"

get_run_directory()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo "${SRUN}"
}
LDIR=$(find ${DBTEXTDIR} -type d -name "[0-9][0-9][0-9]*")

PDIR=$(pwd)

FILES=$(cat $FLIST)

for RUN in $FILES
do
    SUBDIR=$(get_run_directory $RUN)

    ORG_FILE="${DBTEXTDIR}/${SUBDIR}/${RUN}.tar.gz"
    if [[ ! -e "${ORG_FILE}" ]]; then
        echo "Tar ball (original) not found: ${ORG_FILE}"
        continue
    fi
    NDIR=${NEWDIR}/${SUBDIR}/${RUN}
    if [[ ! -d ${NDIR} ]]; then
        echo "Directory with new files not found: ${NDIR}"
        continue
    fi

    # copy and unpack tar ball
    cd ${NEWDIR}/${SUBDIR}/
    cp ${ORG_FILE} .
    tar -xvzf ${RUN}.tar.gz
    rm -f ${RUN}.tar.gz
    # pack again with all files
    tar -cvzf ${RUN}.tar.gz ${RUN}

    cd ${PDIR}
done

cd ${PDIR}
