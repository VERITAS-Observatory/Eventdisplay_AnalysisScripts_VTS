#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_pointingflag.sh : read pointing flag from VTS database

db_pointingflag.sh <run>

or

db_pointingflag.sh <run_start>

examples:

   ./db_pointingflag.sh 64080
"
exit
fi

RUN=$1
QUERY="SELECT vpm_config_mask FROM tblRun_Analysis_Comments WHERE run_id = ${RUN};"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}" | sed 's/\t/|/g'
