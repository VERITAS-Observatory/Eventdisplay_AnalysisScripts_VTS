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
# Set to "" to use the unversioned environment v2dl3Eventdisplay.
# V2DL3VERSION="v0.8.1"
V2DL3VERSION=""
if [[ -n "${V2DL3VERSION}" ]]; then
    CONDA_ENV="v2dl3Eventdisplay-${V2DL3VERSION}"
else
    CONDA_ENV="v2dl3Eventdisplay"
fi

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/$RUN
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR"
fi
echo "Scratch dir: $TEMPDIR"
mkdir -p "$TEMPDIR"

# run list
FILES=$(cat "$RUNLIST")
NRUNS=$(cat "$RUNLIST" | wc -l )
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
    if awk '$1 !~ /^#/ {print $1}' <<< "$env_info" | grep -Fxq "$CONDA_ENV"; then
        echo "Found conda environment '$CONDA_ENV'"
    else
        echo "Error: the conda environment '$CONDA_ENV' does not exist."
        echo "exiting..."
        exit
    fi
}

check_conda_installation

CONDA_BASE=$(conda info --base) || exit 1
source "${CONDA_BASE}/etc/profile.d/conda.sh" || exit 1
conda activate "${CONDA_ENV}" || exit 1
command -v v2dl3-eventdisplay >/dev/null 2>&1 || exit 1
command -v v2dl3-eventdisplay-query-runparameters >/dev/null 2>&1 || exit 1

V2DL3OPT=(
    --fuzzy_boundary zenith 0.05
    --fuzzy_boundary pedvar 0.75
    --save_multiplicity
)
# selection for full-gamma files
EVENTFILTER="${TEMPDIR}/tmp_select.yml"
echo "IsGamma: 1" > "$EVENTFILTER"
echo "Event filter file: ${EVENTFILTER}"
ls -l "${EVENTFILTER}"
cat "${EVENTFILTER}"

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
    echo "${ODIR}"
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
    echo "$RUN"
    ANASUMFILE="$(getNumberedDirectory "$RUN" "$VERITAS_PREPROCESSED_DATA_DIR"/"${VERITAS_ANALYSIS_TYPE:0:2}"/anasum_${CUT})/${RUN}.anasum.root"
    if [[ ! -e ${ANASUMFILE} ]]; then
        echo "File ${ANASUMFILE} not found"
        echo "Skipping run $RUN"
        continue
    fi
    echo "   ANASUM file: ${ANASUMFILE}"
    QUERY_ERROR_LOG="${TEMPDIR}/${RUN}.v2dl3-query.stderr.log"
    : > "${QUERY_ERROR_LOG}"
    result=$(v2dl3-eventdisplay-query-runparameters "${ANASUMFILE}" "${RUN}" 2>"${QUERY_ERROR_LOG}")
    EPOCH=$(printf '%s\n' "$result" | awk -F': ' '/^Epoch:/ {print $2; exit}')
    EFFAREA=$(printf '%s\n' "$result" | awk -F': ' '/^Effective Area:/ {print $2; exit}')
    if [[ -z "$EPOCH" || -z "$EFFAREA" ]]; then
        echo "Error: could not extract epoch/effective area for run ${RUN}."
        cat "${QUERY_ERROR_LOG}"
        echo "Query output: ${result}"
        echo "Skipping run ${RUN}"
        continue
    fi
    EVNDISPVERSION=$(echo "${EFFAREA}" | grep -oE 'v[0-9]+' | head -n 1)
    echo "   Effective area file: $EFFAREA Epoch: $EPOCH"
    DBFITSFILE=$(getNumberedDirectory "$RUN" "$VERITAS_DATA_DIR"/shared/DBFITS)/$RUN.db.fits.gz
    INTERPOLATOR=$(getInterpolator "$EFFAREA")
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
              ( "${EFFAREA,,}" == *redhv* || \
                "${EFFAREA,,}" == *uv* ) ]]; then
            echo "   Skipping full-enclosure conversion for EVNDISPVERSION=${EVNDISPVERSION} and RedHV/UV effective-area file"
            rm -f \
                "${ODIR}/full-enclosure/${RUN}.fits.gz" \
                "${ODIR}/full-enclosure/${RUN}.log" \
                "${ODIR}/full-enclosure-all-events/${RUN}.fits.gz" \
                "${ODIR}/full-enclosure-all-events/${RUN}.log"
            continue
        fi

        echo "   Converting (${m}, ${V2DL3OPT[*]})"

        for p in "" "-all-events"
        do
            if [[ "$p" != "-all-events" ]]; then
                V2DL3SELECT=(--evt_filter "${EVENTFILTER}")
                ls -1 "${EVENTFILTER}"
            else
                V2DL3SELECT=()
            fi
            echo "EVENTFILTER ${V2DL3SELECT[*]}"

            mkdir -p ${ODIR}/${m}${p}
            rm -f ${ODIR}/${m}${p}/"${RUN}".log

            if [[ -s "${QUERY_ERROR_LOG}" ]]; then
                cat "${QUERY_ERROR_LOG}" >> ${ODIR}/${m}${p}/"${RUN}".log
            fi

            v2dl3-eventdisplay \
                --${m} \
                "${V2DL3OPT[@]}" "${V2DL3SELECT[@]}" \
                --file_pair "${ANASUMFILE}" "$VERITAS_EVNDISP_AUX_DIR"/EffectiveAreas/"${EFFAREA}" \
                --logfile ${ODIR}/${m}${p}/"${RUN}".log \
                --instrument_epoch "${EPOCH}" \
                --interpolator_name "${INTERPOLATOR}" \
                --db_fits_file "${DBFITSFILE}" \
                ${ODIR}/${m}${p}/"${RUN}".fits.gz \
                2>> ${ODIR}/${m}${p}/"${RUN}".log

            python --version >> ${ODIR}/${m}${p}/"${RUN}".log 2>&1
            conda list -n "${CONDA_ENV}" >> ${ODIR}/${m}${p}/"${RUN}".log 2>&1
            PDIR=$(pwd)
            cd "${PDIR}" || exit
        done
    done
done

exit
