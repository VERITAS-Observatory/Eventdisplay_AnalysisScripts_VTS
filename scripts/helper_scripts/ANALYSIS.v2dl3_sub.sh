#!/bin/bash
# script to run V2DL3
# (convert anasum output to FITS-DL3)
# run point-like and full-enclosure analysis

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source $EVNDISPSYS/setObservatory.sh VTS
fi
# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
RUNLIST=RRUNLIST
ODIR=OODIR
CUT=CCUT

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$RUN
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

# run list
FILES=`cat "$RUNLIST"`
NRUNS=`cat "$RUNLIST" | wc -l `
echo "total number of runs to analyze: $NRUNS"
echo

# make output directory if it doesn't exist
mkdir -p ${ODIR}
echo -e "Output files will be written to:\n ${ODIR}"

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
export PYTHONPATH=\$PYTHONPATH:${V2DL3SYS}

V2DL3OPT="--fuzzy_boundary zenith 0.05 --fuzzy_boundary pedvar 0.5 --save_multiplicity"
# selection for full-gamma files
EVENTFILTER="${TEMPDIR}/tmp_select.yml"
echo "IsGamma: 1" > $EVENTFILTER
echo "Event filter file: ${EVENTFILTER}"
ls -l ${EVENTFILTER}
cat ${EVENTFILTER}

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

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${TEMPDIR}:/opt/DDIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${TEMPDIR}:/opt/TEMPDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_DATA_DIR=/opt/VERITAS_DATA_DIR,VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,INDIR=/opt/INDIR,TEMPDIR=/opt/TEMPDIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    DDIR="/opt/DDIR/"
    echo "APPTAINER DDIR: $DDIR"
fi


for RUN in $FILES
do
    echo $RUN
    ANASUMFILE="$(getNumberedDirectory $RUN $VERITAS_PREPROCESSED_DATA_DIR/${VERITAS_ANALYSIS_TYPE:0:2}/anasum_${CUT})/${RUN}.anasum.root"
    if [[ ! -e ${ANASUMFILE} ]]; then
        echo "File ${ANASUMFILE} not found"
        echo "Skipping run $RUN"
        continue
    fi
    echo "   ANASUM file: ${ANASUMFILE}"
    cp -v ${ANASUMFILE} ${TEMPDIR}
    if [ -n "$EVNDISP_APPTAINER" ]; then
        ED_ANASUMFILE="/opt/TEMPDIR/$(basename ${ANASUMFILE})"
    else
        ED_ANASUMFILE="${ED_ANASUMFILE}"
    fi
    EFFAREA=$($EVNDISPSYS/bin/printAnasumRunParameter ${ED_ANASUMFILE} ${RUN} -effareafile)
    EPOCH=$($EVNDISPSYS/bin/printRunParameter ${ED_ANASUMFILE} -epoch)
    echo "   Effective area file: $EFFAREA Epoch: $EPOCH"
    DBFITSFILE=$(getNumberedDirectory $RUN $VERITAS_DATA_DIR/shared/DBFITS)/$RUN.db.fits.gz
    if [[ ! -e ${DBFITSFILE} ]]; then
        echo "DB File ${DBFITSFILE} not found"
        echo "Skipping run $RUN"
        continue
    fi
    echo "   Using DBFits file ${DBFITSFILE}"

    for m in "point-like" "full-enclosure"
    do
        echo "   Converting (${m}, ${V2DL3OPT})"

        for p in "" "-all-events"
        do
            if [[ "$p" != "-all-events" ]]; then
                V2DL3SELECT="--evt_filter ${EVENTFILTER}"
                ls -1 ${EVENTFILTER}
            else
                V2DL3SELECT=""
            fi
            echo "EVENTFILTER $V2DL3SELECT"

            mkdir -p ${ODIR}/${m}${p}
            rm -f ${ODIR}/${m}${p}/${RUN}.log

            python ${V2DL3SYS}/pyV2DL3/script/v2dl3_for_Eventdisplay.py \
                --${m} \
                ${V2DL3OPT} ${V2DL3SELECT} \
                --file_pair ${ANASUMFILE} $VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFAREA} \
                --logfile ${ODIR}/${m}${p}/${RUN}.log \
                --instrument_epoch ${EPOCH} \
                --db_fits_file ${DBFITSFILE} \
                ${ODIR}/${m}${p}/${RUN}.fits.gz

            python --version >> ${ODIR}/${m}${p}/${RUN}.log
            conda list -n v2dl3Eventdisplay >> ${ODIR}/${m}${p}/${RUN}.log
            PDIR=$(pwd)
            cd ${V2DL3SYS}
            echo "GIT status: " >> ${ODIR}/${m}${p}/${RUN}.log
            git rev-parse HEAD >> ${ODIR}/${m}${p}/${RUN}.log
            cd ${PDIR}
        done
    done
done

exit
