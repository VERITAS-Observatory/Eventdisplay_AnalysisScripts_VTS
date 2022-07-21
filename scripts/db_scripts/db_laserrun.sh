#!/bin/bash
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
db_laserrun.sh: read corresponding laser run from VTS database

db_laserrun.sh <run_start>

examples:

   ./db_laserrun.sh 64080
"
exit
fi

RUN=$1
QUERY="SELECT info.run_id, grp_cmt.excluded_telescopes, info.config_mask FROM tblRun_Info AS info, tblRun_Group AS grp, tblRun_GroupComment AS grp_cmt, (SELECT group_id FROM tblRun_Group WHERE run_id=$1) AS run_grp WHERE grp_cmt.group_id = run_grp.group_id AND grp_cmt.group_type='laser' AND grp_cmt.group_id=grp.group_id AND grp.run_id=info.run_id AND (info.run_type='flasher' OR info.run_type='laser');"

$($EVNDISPSCRIPTS/db_scripts/db_mysqldb.sh) -e "USE VERITAS; ${QUERY}" | sed 's/\t/|/g'
