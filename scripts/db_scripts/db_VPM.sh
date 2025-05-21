#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_VPM: read VPM data from VTS database

./db_VPM.sh <start date> <stop date> <tel id>

"
exit
fi

STARTDATE="$1"
ENDDATE="$2"
TELID="$3"

STARTMJD=$($EVNDISPSYS/bin/printMJD "${STARTDATE}")
ENDMJD=$($EVNDISPSYS/bin/printMJD "${ENDDATE}")

if [[ "${STARTDATE}" == *NULL* ]] || [[ "${ENDDATE}" == *NULL* ]]; then
    echo ""
else
    QUERY="SELECT mjd,ra,decl FROM tblPointing_Monitor_Telescope${TELID}_Calibrated_Pointing WHERE mjd<=${ENDMJD} AND mjd>=${STARTMJD}"
    $($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}"  | sed 's/\t/|/g'
fi
