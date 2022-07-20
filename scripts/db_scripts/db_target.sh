#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_target.sh : read target info from VTS database

db_target.sh "target name"

examples:

   ./db_target.sh Crab

"
exit
fi

TARGET=$1
QUERY="select * from tblObserving_Sources where source_id like convert( _utf8 '$TARGET' using latin1);"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
