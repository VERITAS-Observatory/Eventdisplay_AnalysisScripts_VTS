#!/bin/bash
# script to run V2DL3
# (convert anasum output to FITS-DL3)
# run point-like and full-enclosure analysis

# Don't do set -e.
# set -e

# parameters replaced by parent script using sed
RUNLIST=RRUNLIST
ODIR=OODIR
CUT=CCUT
V2DL3VERSION="v0.8.1"

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
    env_name="v2dl3Eventdisplay-${V2DL3VERSION}"
    if [[ "$env_info" == *"$env_name"* ]]; then
        echo "Found conda environment '$env_name'"
    else
        echo "Error: the conda environment '$env_name' does not exist."
        echo "exiting..."
        exit
    fi
}

check_conda_installation

# HTCondor starts a non-interactive shell and does not source the user's
# interactive shell initialization.  Therefore the conda shell function is
# not available even when `conda` itself is on PATH.
CONDA_BASE=$(conda info --base) || {
    echo "Error: unable to determine the Conda base installation."
    exit 1
}
source "${CONDA_BASE}/etc/profile.d/conda.sh" || {
    echo "Error: unable to initialize Conda from ${CONDA_BASE}."
    exit 1
}

CONDA_ENV="v2dl3Eventdisplay-${V2DL3VERSION}"
conda activate "${CONDA_ENV}" || {
    echo "Error: unable to activate Conda environment '${CONDA_ENV}'."
    exit 1
}

python -m pip install -e "${V2DL3SYS%/}" || {
    echo "Error: unable to install V2DL3 from ${V2DL3SYS}."
    exit 1
}

command -v v2dl3-eventdisplay || {
    echo "Error: v2dl3-eventdisplay is not available in Conda environment '${CONDA_ENV}'."
    exit 1
}

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

# interpolator; might depend on IRF type
# RegularGridInterpolator is generally the default
# v491 IRFs are partly incomplete and require KNeighborsRegressor
getInterpolator()
{
    EFF="$1"
    if [[ "$EFF" != *v491* ]]; then
        INTER="RegularGridInterpolator"
    else
        if [[ "$EFF" == *V5* ]] || [[ "$EFF" == *V4* ]] || [[ "$EFF" == *CARE_RedHV* ]]; then
            INTER="RegularGridInterpolator"
        else
            INTER="KNeighborsRegressor"
        fi
    fi
    echo ${INTER}
}

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
    result=$(v2dl3-eventdisplay-query-runparameters ${ANASUMFILE} ${RUN})
    EPOCH=$(echo $result |  awk '{print $2}')
    EFFAREA=$(echo $result | awk '{print $5}')
    # The effective-area filename is the authoritative source for the
    # EventDisplay generation and HV configuration used for this run.
    EVNDISPVERSION=$(echo "${EFFAREA}" | grep -oE 'v[0-9]+' | head -n 1)
    echo "   Effective area file: $EFFAREA Epoch: $EPOCH"
    echo "   EventDisplay version from effective area: ${EVNDISPVERSION}"
    DBFITSFILE=$(getNumberedDirectory $RUN $VERITAS_DATA_DIR/shared/DBFITS)/$RUN.db.fits.gz
    INTERPOLATOR=$(getInterpolator $EFFAREA)
    if [[ ! -e ${DBFITSFILE} ]]; then
        echo "DB File ${DBFITSFILE} not found"
        echo "Skipping run $RUN"
        continue
    fi
    echo "   Using DBFits file ${DBFITSFILE}"

    for m in "point-like" "full-enclosure"
    do
        if [[ "$m" == "full-enclosure" && \
              "${EVNDISPVERSION,,}" == *v490* && \
              "${EFFAREA,,}" == *redhv* ]]; then
            echo "   Skipping full-enclosure conversion for EVNDISPVERSION=${EVNDISPVERSION} and redHV ANASUM file"
            continue
        fi

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

            v2dl3-eventdisplay \
                --${m} \
                ${V2DL3OPT} ${V2DL3SELECT} \
                --file_pair ${ANASUMFILE} $VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFAREA} \
                --logfile ${ODIR}/${m}${p}/${RUN}.log \
                --instrument_epoch ${EPOCH} \
                --interpolator_name ${INTERPOLATOR} \
                --db_fits_file ${DBFITSFILE} \
                ${ODIR}/${m}${p}/${RUN}.fits.gz

            python --version >> ${ODIR}/${m}${p}/${RUN}.log
            conda list -n v2dl3Eventdisplay-${V2DL3VERSION} >> ${ODIR}/${m}${p}/${RUN}.log
            PDIR=$(pwd)
            cd ${PDIR}
        done
    done
done

exit
