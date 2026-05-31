#!/bin/bash
# Script to merge and link to Evndisp datasets
# (this is preliminary with hardwired settings and
# not to be used for general usage)
#

set -e

ANATYPE="AP"

I1="$VERITAS_IRFPRODUCTION_DIR/v4N/${ANATYPE}/CARE_202404"
I2="$VERITAS_IRFPRODUCTION_DIR/v4N/${ANATYPE}/CARE_June2020"
ODIR="$VERITAS_IRFPRODUCTION_DIR/v4N/${ANATYPE}/CARE_24_20"

echo "$I1"
mapfile -t EPOCHDIR < <(find "$I1" -maxdepth 1 -type d -name "V6*")

for epoch_dir in "${EPOCHDIR[@]}"; do
    EPOCH=$(basename "$epoch_dir")
    echo "EPOCH $EPOCH"

    mapfile -t PARDIR < <(find "$epoch_dir" -maxdepth 1 -type d -name "ze*")

    for par_dir in "${PARDIR[@]}"; do
        TDIR="${ODIR}/${EPOCH}/$(basename "$par_dir")"
        mkdir -p "$TDIR"

        mapfile -t EFILES < <(find "$par_dir" -maxdepth 1 -name "*.root.zst")
        for efile in "${EFILES[@]}"; do
            OFILE=$(basename "$efile")
            OFILE="1${OFILE:1}"
            ln -f -s "$efile" "$TDIR/$OFILE"
        done

        if [[ -e "$I2/$EPOCH/$(basename "$par_dir")" ]]; then
            mapfile -t EFILES < <(find "$I2/$EPOCH/$(basename "$par_dir")" -maxdepth 1 -name "*.root.zst")
            for efile in "${EFILES[@]}"; do
                OFILE=$(basename "$efile")
                OFILE="2${OFILE:1}"
                ln -f -s "$efile" "$TDIR/$OFILE"
            done
        else
            echo "NOT IN I2: $I2/$EPOCH/$(basename "$par_dir")"
        fi
     done
done
