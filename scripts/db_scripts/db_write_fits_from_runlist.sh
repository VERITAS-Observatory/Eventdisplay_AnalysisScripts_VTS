#!/bin/bash
# 
# Write DB FITS files from a run list

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_write_fits_from_runlist.sh: write DB FITS files from run list

"
exit
fi

RUNS=$(cat $1)
IDIR="$VERITAS_DATA_DIR/shared/DBTEXT/"
ODIR="./"

for R in $RUNS
do
    python ./db_write_fits.py --run ${R} --input_path ${IDIR} --output_path ${ODIR}
done

