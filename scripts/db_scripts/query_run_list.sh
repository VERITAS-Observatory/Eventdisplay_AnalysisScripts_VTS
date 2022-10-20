#!/bin/bash
#
# extract information from VERITAS database required
# for evndisp analysis for a list of runs
#

RUNS=$(cat $1)

for R in $RUNS
do
    ./db_run.sh ${R}
done
