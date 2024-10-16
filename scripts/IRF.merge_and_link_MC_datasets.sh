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

echo $I1
EPOCHDIR=$(find $I1 -maxdepth 1 -type d -name "V6*")

for E in $EPOCHDIR; do
    EPOCH=$(basename $E)
    echo "EPOCH $EPOCH"

    PARDIR=$(find $E  -maxdepth 1 -type d -name "ze*")

    for P in $PARDIR; do
        TDIR=${ODIR}/${EPOCH}/$(basename $P)
        mkdir -p $TDIR

        EFILES=$(find $P -maxdepth 1 -name "*.root.zst")
        for E in $EFILES; do
            OFILE=$(basename $E)
            OFILE="1${OFILE:1}"
            ln -f -s $E $TDIR/$OFILE
        done

        if [[ -e $I2/$EPOCH/$(basename $P) ]]; then
            EFILES=$(find $I2/$EPOCH/$(basename $P) -maxdepth 1 -name "*.root.zst")
            for E in $EFILES; do
                OFILE=$(basename $E)
                OFILE="2${OFILE:1}"
                ln -f -s $E $TDIR/$OFILE
            done
        else
            echo "NOT IN I2: $I2/$EPOCH/$(basename $P)"
        fi
     done
done
