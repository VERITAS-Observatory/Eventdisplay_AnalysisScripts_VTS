#!/bin/bash
#
# Extract information from VERITAS database required
# for evndisp analysis for a list of runs

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
query_run_list.sh: query DB and write DBTEXT files

./query_run_list <run list> <overwrite=0/1 (default=0)

"
exit
fi

RUNS=$(cat $1)
[[ "$2" ]] && OVERW=$2 || OVERW="0"

IDIR="$VERITAS_DATA_DIR/shared/DBTEXT/"

for R in $RUNS
do
    ./db_run.sh ${R} ${OVERW}
done
