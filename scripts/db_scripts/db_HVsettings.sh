#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_HVsettings.sh: read HV pixel setting from VTS database

db_HVsettings.sh <start date> <end date> <tel_id>

(tel_id should start counting at zero)
"
exit
fi

STARTDATE="$1"
ENDDATE="$2"
TELID="$3"

QUERY="select * FROM tblHV_Telescope${TELID}_Status WHERE channel > 0 AND (db_start_time >=\"${STARTDATE}\" - INTERVAL 1 MINUTE) AND (db_start_time <= \"${ENDDATE}\" );"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
