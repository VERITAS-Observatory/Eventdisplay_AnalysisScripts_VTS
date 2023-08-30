#!/bin/bash
# script to run V2DL3 
# (convert anasum output to FITS-DL3)
# run point-like and full-enclosure analysis

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS
# Don't do set -e. 
# set -e

# parameters replaced by parent script using sed
RUNLIST=RRUNLIST
ODIR=OODIR
CUT=CCUT


# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`
# Directory with preprocessed data
INPUTDIR="$VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/anasum/"
# V2DL3 code
V2DL3="$EVNDISPSYS/../V2DL3/"

# run list
FILES=`cat "$RUNLIST"`
NRUNS=`cat "$RUNLIST" | wc -l ` 
echo "total number of runs to analyze: $NRUNS"
echo

# make output directory if it doesn't exist
mkdir -p ${ODIR}
echo -e "Output files will be written to:\n ${ODIR}"

# run scripts are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/${DATE}-$(uuidgen)/V2DL3"
mkdir -p "$LOGDIR"
echo -e "Log files will be written to:\n $LOGDIR"

check_conda_installation()
{
    if command -v conda &> /dev/null; then
        echo "Found conda installation."
    else
        echo "Error: found no conda installation."
        echo "exiting..."
        exit
    fi
    env_info=$(conda info --envs)
    env_name="v2dl3Eventdisplay"
    if [[ "$env_info" == *"$env_name"* ]]; then
        echo "Found conda environment '$env_name'"
    else
        echo "Error: the conda environment '$env_name' does not exist."
        echo "exiting..."
        exit
    fi
}

check_conda_installation

source activate base
conda activate v2dl3Eventdisplay
export PYTHONPATH=\$PYTHONPATH:${V2DL3}

V2DL3OPT="--fuzzy_boundary zenith 0.05 --fuzzy_boundary pedvar 0.5 --save_multiplicity"
 
# directory schema for preprocessed files
getNumberedDirectory()
{
    TRUN="$1"
    IDIR="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${IDIR}/${TRUN:0:1}/"
    else
        ODIR="${IDIR}/${TRUN:0:2}/"
    fi
    echo ${ODIR}
}

for RUN in $FILES
do
    echo $RUN
    ANASUMFILE="$(getNumberedDirectory $RUN $VERITAS_DATA_DIR/processed_data_${EDVERSION}/${VERITAS_ANALYSIS_TYPE:0:2}/anasum_${CUT})/${RUN}.anasum.root"
    if [[ ! -e ${ANASUMFILE} ]]; then
        echo "File ${ANASUMFILE} not found"
        echo "Skipping run $RUN"
        continue
    fi
    echo "   ANASUM file: ${ANASUMFILE}"
    EFFAREA=$($EVNDISPSYS/bin/printAnasumRunParameter ${ANASUMFILE} ${RUN} -effareafile)
    echo "   Effective area file: $EFFAREA"

    for m in "point-like" "full-enclosure"
    do
        echo "   Converting (${m}, ${V2DL3OPT})"

        mkdir -p ${ODIR}/${m}
        rm -f ${ODIR}/${m}/${RUN}.log

        python ${V2DL3}/pyV2DL3/script/v2dl3_for_Eventdisplay.py \
            --${m} \
            ${V2DL3OPT} \
            --file_pair ${ANASUMFILE} $VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFAREA} \
            --logfile ${ODIR}/${m}/${RUN}.log \
            ${ODIR}/${m}/${RUN}.fits.gz
    done
done

exit