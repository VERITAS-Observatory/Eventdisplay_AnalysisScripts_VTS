#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_rawpointing: read raw positioner data from VTS database

./db_rawpointing.sh <start date> <stop date> <tel id>

"
exit 0
fi

STARTDATE="$1"
ENDDATE="$2"
TELID="$3"

TIMESTART=${STARTDATE//:/}
TIMESTART=${TIMESTART//-/}
TIMESTART=${TIMESTART// /}
TIMESTART="${TIMESTART}000"
TIMEEND=${ENDDATE//:/}
TIMEEND=${TIMEEND//-/}
TIMEEND=${TIMEEND// /}
TIMEEND="${TIMEEND}000"

if [[ "${STARTDATE}" == *NULL* ]] || [[ "${TIMEEND}" == *NULL* ]]; then
    echo ""
else
    QUERY="SELECT timestamp, elevation_raw, azimuth_raw, elevation_meas, azimuth_meas, elevation_target, azimuth_target FROM tblPositioner_Telescope${TELID}_Status WHERE timestamp >= ${TIMESTART} AND timestamp <= ${TIMEEND};"
    $($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
fi
