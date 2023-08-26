#!/bin/bash
#

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
db_weather: read weather data from VTS database

./db_weather.sh <start date> <stop date>

"
exit
fi

STARTDATE="$1"
ENDDATE="$2"

QUERY="SELECT timestamp, WS_mph_Avg, WS_mph_Max, WS_mph_Min, WindDir, AirTF_Avg, RH, Rain_in_Tot, SlrW_Avg, SlrkJ_Tot, BP_mbar_Avg FROM tblWeather_Status WHERE timestamp >= \"${STARTDATE}\" AND timestamp < \"${ENDDATE}\""
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
