#!/bin/bash
#

if [ $# -lt 2 ] || [ "$1" = "-h" ]; then
echo "
db_L3: read l3 data from VTS database

./db_L3.sh <start date> <stop date>

"
exit
fi

STARTDATE="$1"
ENDDATE="$2"

TIMESTART=${STARTDATE//:/}
TIMESTART=${TIMESTART//-/}
TIMESTART=${TIMESTART// /}
TIMESTART="${TIMESTART}000"
TIMEEND=${ENDDATE//:/}
TIMEEND=${TIMEEND//-/}
TIMEEND=${TIMEEND// /}
TIMEEND="${TIMEEND}000"

QUERY="SELECT timestamp, run_id, L3, L3orVDAQBusy, VDAQBusy, SpareBusy, PED, OC, VDAQBusyScaler, L3orVDAQBusyScaler, TenMHzScaler FROM tblL3_Array_TriggerInfo WHERE timestamp >= ${TIMESTART} AND timestamp <= ${TIMEEND};"
$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}"  | sed 's/\t/|/g'
