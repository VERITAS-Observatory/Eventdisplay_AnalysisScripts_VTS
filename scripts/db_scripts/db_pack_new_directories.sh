# pack newly written directories extacted from the DB
# with query_run_list.sh
#

DBTEXTDIR="$VERITAS_DATA_DIR/DBTEXT/"

get_run_directory()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo "${DBTEXTDIR}/${SRUN}"
}
LDIR=$(find ${DBTEXTDIR} -type d -name "[0-9][0-9][0-9]*")

PDIR=$(pwd)

for L in ${LDIR}
do
    RUN=$(basename $L)
    TDIR=$(get_run_directory $RUN)
    echo $RUN $TDIR
    cd $TDIR
    tar -czf ${RUN}.tar.gz ${RUN}
done

cd ${PDIR}

