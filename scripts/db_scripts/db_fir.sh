#!/bin/bash
#

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
db_fir: read FIR data from VTS database

./db_fir.sh <start date> <stop date>

"
exit
fi

STARTDATE="$1"
ENDDATE="$2"

QUERY="SELECT timestamp, telescope_id, ambient_temp, radiant_sky_temp FROM tblFIR_Pyrometer_Info  WHERE timestamp >= \"${STARTDATE}\" AND timestamp < \"${ENDDATE}\""
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
