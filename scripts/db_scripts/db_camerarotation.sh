#!/bin/bash
#

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
db_camerarotation.sh read camera rotation from VTS database

db_camerarotation.sh <start date> <end date>

examples:

   ./db_camerarotation.sh \"2023-10-20 09:50:10\" \"2023-10-20 10:25:45\"
"
exit
fi

STARTDATE="$1"
ENDDATE="$2"
QUERY="select telescope_id, version, pmt_rotation from tblPointing_Monitor_Camera_Parameters where start_date <=\"${STARTDATE}\" and end_date >\"${ENDDATE}\" ORDER BY version DESC"
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}"  | sed 's/\t/|/g'
