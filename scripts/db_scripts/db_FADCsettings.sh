#!/bin/bash
#

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
db_L1_TriggerInfo.sh: read L1 trigger info from VTS database

db_L1_TriggerInfo.sh <start date> <end date> <tel_id>

(tel_id should start counting at zero)
"
exit
fi

STARTDATE="$1"
ENDDATE="$2"
TELID="$3"

QUERY="select c.pixel_id , s.fadc_id, c.fadc_channel from tblFADC_Slot_Relation as s, tblFADC_Channel_Relation as c where s.db_start_time < \"${STARTDATE}\" and c.db_start_time < \"${STARTDATE}\" and ( s.db_end_time IS NULL or s.db_end_time > \"${ENDDATE}\" ) and ( c.db_end_time IS NULL or c.db_end_time > \"${ENDDATE}\" ) and s.fadc_crate=c.fadc_crate and s.fadc_slot=c.fadc_slot and s.telescope_id=c.telescope_id and c.pixel_id IS NOT NULL and s.telescope_id=${TELID} order by c.pixel_id ;"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
