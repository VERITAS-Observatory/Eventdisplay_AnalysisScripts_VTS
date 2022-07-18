#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_VPM: read VPM data from VTS database

db_VPM.sh <tel id> <start date> <stop date>

"
exit
fi

TELID="$1"
STARTDATE="$2"
ENDDATE="$3"

STARTMJD=$($EVNDISPSYS/bin/printMJD "${STARTDATE}")
ENDMJD=$($EVNDISPSYS/bin/printMJD "${ENDDATE}")

QUERY="SELECT mjd,ra,decl FROM tblPointing_Monitor_Telescope${TELID}_Calibrated_Pointing WHERE mjd<=${ENDMJD} AND mjd>=${STARTMJD}"
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}"  | sed 's/\t/|/g'
