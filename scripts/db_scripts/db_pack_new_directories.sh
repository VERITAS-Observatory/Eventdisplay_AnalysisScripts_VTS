#!/bin/bash
# pack newly written directories extracted from the DB
# with query_run_list.sh
#

DBTEXTDIR="$VERITAS_DATA_DIR/shared/DBTEXT"

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
PDIR=$(pwd)

while IFS= read -r -d '' L
do
    RUN=$(basename "$L")
    TDIR=$(get_run_directory "$RUN")

    # Only operate on the run directory directly below its expected parent.
    if [[ "$(dirname "$L")" != "$TDIR" ]]; then
        echo "Skipping unexpected directory: $L" >&2
        continue
    fi

    echo "$RUN" "$TDIR"/"$RUN"
    cd "$TDIR" || exit

    ARCHIVE="${RUN}.tar.gz"
    TEMP_ARCHIVE="${ARCHIVE}.$$"

    # Do not remove the source directory unless the temporary archive was
    # created successfully and can be read back by tar.
    if tar -czf "$TEMP_ARCHIVE" -- "$RUN" \
        && tar -tzf "$TEMP_ARCHIVE" >/dev/null \
        && mv -f -- "$TEMP_ARCHIVE" "$ARCHIVE"; then
        rm -rf -- "$RUN"
    else
        echo "Failed to create or validate $TDIR/$ARCHIVE; keeping $TDIR/$RUN" >&2
        rm -f -- "$TEMP_ARCHIVE"
    fi
done < <(find "${DBTEXTDIR}" -type d -name "[0-9][0-9][0-9]*" -print0)

cd "${PDIR}" || exit
