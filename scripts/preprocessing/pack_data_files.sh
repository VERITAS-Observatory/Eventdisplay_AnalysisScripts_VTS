#!/bin/bash
# Prepare Eventdisplay data products of a certain
# type from a run list into tar balls
#
# Files are packed per starting run number
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
Pack Eventdisplay data products from run list

./prepare_runlist_after_dqm.sh <Eventdisplay data type> <runlist> <outputdirectoryname>

data type: evndisp, mscw

Note! Copies files to temporary diretory $VERITAS_USER_DATA_DIR/tmp_packing/<outputdirectoryname>

"
exit
fi

DATATYPE=${1}
RUNLIST=${2}

ANATYPE="AP"
VERSION="v490"

RUNS=$(cat $RUNLIST)

TMPDATADIR="$VERITAS_USER_DATA_DIR/tmp_packing/${3}/${DATATYPE}"
mkdir -p ${TMPDATADIR}

get_suffix()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo ${SRUN}
}

get_file_name()
{
    RRUN=${1}
    SRUN=$(get_suffix ${RRUN})
    if [[ $DATATYPE == "evndisp" ]]; then
        echo "$VERITAS_DATA_DIR/processed_data_${VERSION}/${ANATYPE}/${DATATYPE}/${SRUN}/${RRUN}.root"
    elif [[ $DATATYPE == "mscw" ]]; then
        echo "$VERITAS_DATA_DIR/processed_data_${VERSION}/${ANATYPE}/${DATATYPE}/${SRUN}/${RRUN}.mscw.root"
    fi
}

for R in $RUNS
do
    F=$(get_file_name $R)
    if [[ ! -f ${F} ]]; then
        echo "RUN ${R} not processed for ${DATATYPE} (${ANATYPE})"
    fi
    echo "FOUND ${F}"
    SRUN=$(get_suffix ${R})
    mkdir -p ${TMPDATADIR}/${SRUN}
    cp -f -v ${F} ${TMPDATADIR}/${SRUN}
done

DTOPACK=$(find ${TMPDATADIR}  -mindepth 1 -name "[0-9]*" -type d)
for D in ${DTOPACK}
do
    echo "Packing $D"
    tar -cvzf ${D}.${DATATYPE}.tar.gz ${D}
done
