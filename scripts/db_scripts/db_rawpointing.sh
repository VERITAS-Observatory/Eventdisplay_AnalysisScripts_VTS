#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_rawpointing: read positioner data from VTS database

./db_rawpointing.sh <tel id> <start date> <stop date>

"
exit
fi

TELID="$1"
STARTDATE="$2"
ENDDATE="$3"

TIMESTART=${STARTDATE//:/}
TIMESTART=${TIMESTART//-/}
TIMESTART=${TIMESTART// /}
TIMESTART="${TIMESTART}000"
TIMEEND=${ENDDATE//:/}
TIMEEND=${TIMEEND//-/}
TIMEEND=${TIMEEND// /}
TIMEEND="${TIMEEND}000"

QUERY="SELECT timestamp, elevation_raw, azimuth_raw, elevation_meas, azimuth_meas, elevation_target, azimuth_target FROM tblPositioner_Telescope${TELID}_Status WHERE timestamp >= ${TIMESTART} AND timestamp <= ${TIMEEND};"
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
