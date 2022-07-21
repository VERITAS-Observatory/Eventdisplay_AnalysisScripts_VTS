#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_L1_TriggerInfo.sh: read L1 trigger info from VTS database

db_L1_TriggerInfo.sh <run>

examples:

   ./db_L1_TriggerInfo.sh 64080
"
exit
fi

RUN=$1
QUERY="select timestamp, telescope_id, pixel_id, rate from tblL1_TriggerInfo, tblRun_Info where timestamp >= tblRun_Info.data_start_time - INTERVAL 1 MINUTE AND timestamp <=  tblRun_Info.data_end_time + INTERVAL 1 MINUTE AND tblRun_Info.run_id=${RUN};"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
