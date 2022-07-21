#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_rundqm.sh: read run DQM from VTS database

db_rundqm.sh <run>

or

db_rundqm.sh <run_start> <run_end>

examples:

   ./db_rundqm.sh 64080

   ./db_rundqm.sh 64080 64083

"
exit
fi

RUNSTART=$1
[[ "$2" ]] && RUNSTOPP=$2 || RUNSTOPP=$1
QUERY="SELECT run_id , data_category   , status   , status_reason , tel_cut_mask , usable_duration , time_cut_mask , light_level , vpm_config_mask , authors  , comment from tblRun_Analysis_Comments where run_id>=${RUNSTART} and run_id<=${RUNSTOPP};"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}" | sed 's/\t/|/g'
