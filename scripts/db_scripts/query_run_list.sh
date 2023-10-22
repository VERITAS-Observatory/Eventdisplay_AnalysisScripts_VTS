#!/bin/bash
#
# Extract information from VERITAS database required
# for evndisp analysis for a list of runs

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
query_run_list.sh: query DB and write DBTEXT files 

./query_run_list <run list> <DBFITS=TRUE/FALSE (default=FALSE)>

Allow to write DB FITS files at the same time


"
exit
fi

RUNS=$(cat $1)
[[ "$2" ]] && DBFITS=$2 || DBFITS="FALSE"
IDIR="$VERITAS_DATA_DIR/shared/DBTEXT/"
ODIR="./"

for R in $RUNS
do
    ./db_run.sh ${R}
#    if [[ $DBFITS == "TRUE" ]]; then
#        python ./db_write_fits.py \
#            --run ${R} \
#            --input_path ${IDIR} \
#            --output_path ${ODIR}
#    fi
done

