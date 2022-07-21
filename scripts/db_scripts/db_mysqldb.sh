#!/bin/bash
#

if [ "$1" = "-h" ]; then
echo "
db_mysqldb.sh: return mysql DB command including VERITAS DB from EVNDISP.globalrunparameter

db_mysqldb.sh

"
exit
fi

# get url of veritas db
PARAFILE="${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/EVNDISP.global.runparameter"
MYSQLDB=`grep '^\*[ \t]*DBSERVER[ \t]*mysql://' ${PARAFILE} | egrep -o '[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}'`
if [ ! -n "$MYSQLDB" ] ; then
    echo "Error: DBSERVER parameters not found in ${PARAFILE}"
    exit 1
fi
echo "mysql -u readonly -h ${MYSQLDB} -A"
