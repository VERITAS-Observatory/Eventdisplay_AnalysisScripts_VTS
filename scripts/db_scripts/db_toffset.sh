#!/bin/bash
#

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
db_toffset: read relative toffsets from VERITAS ID

db_toffset.sh <run> <tel_id>

(tel_id should start counting at 1)
"
exit
fi

RUN="$1"
TELID="$2"
LOWGAIN="0"

QUERY="SELECT * FROM(SELECT tbl.channel_id, tbl.toffset_mean, tbl.toffset_var FROM tblEventDisplay_Analysis_Calibration_Flasher AS tbl WHERE tbl.telescope = ${TELID} AND  tbl.run_id = ${RUN} AND tbl.high_low_gain_flag = $LOWGAIN ORDER BY tbl.update_time DESC ) AS BIG_table GROUP BY channel_id;"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VOFFLINE; ${QUERY}" | sed 's/\t/|/g'
