#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_runinfo.sh : read runinfo from VTS database

db_runinfo.sh <run>

or

db_runinfo.sh <run_start> <run_end>

examples:

   ./db_runinfo.sh 64080

   ./db_runinfo.sh 64080 64083

"
exit
fi

RUNSTART=$1
[[ "$2" ]] && RUNSTOPP=$2 || RUNSTOPP=$1
QUERY="select * from tblRun_Info where run_id>=${RUNSTART} and run_id<=${RUNSTOPP};"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
