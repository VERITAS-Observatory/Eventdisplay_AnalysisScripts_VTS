#!/bin/bash
#

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
db_lidar: read lidar data from VTS database

./db_lidar.sh <start date> <stop date>

"
exit 0
fi

STARTDATE="$1"
ENDDATE="$2"

if [[ "${STARTDATE}" == *NULL* ]] || [[ "${ENDDATE}" == *NULL* ]]; then
    echo ""
else
    QUERY="SELECT * FROM tblLIDAR_Info WHERE timestamp >= \"${STARTDATE}\" AND timestamp < \"${ENDDATE}\""
    $($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
fi
