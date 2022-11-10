#!/bin/sh
#
# submit a list of scripts to HTCondor job submission system
#
# 1. submits all *.sh files in the given directory
# 2. searches for *.condor files for job submission details
#
set -e

if [ $# -lt 1 ]
then
    echo "
    ./submit_scripts_to_htcondor.sh <job directory> <submit/nosubmit>

    "
    exit
fi

JDIR=${1}

SUBMITF=${1}/submit.txt
rm -f ${SUBMITF}
touch ${SUBMITF}

echo "Writing HTCondor job submission file ${SUBMITF}"

echo "executable = \$(file)" >>  ${SUBMITF}
echo "log = \$(file).log" >>  ${SUBMITF}
echo "output = \$(file).output" >>  ${SUBMITF}
echo "error = \$(file).error" >>  ${SUBMITF}

echo "$(grep -h request_memory ${JDIR}/*.condor | sort -u)"  >>  ${SUBMITF}
echo "$(grep -h request_disk ${JDIR}/*.condor | sort -u)" >>  ${SUBMITF}
echo "getenv = True" >>  ${SUBMITF}
echo "max_materialize = 50" >>  ${SUBMITF}
echo "queue file matching files *.sh" >> ${SUBMITF}

PDIR=$(pwd)
if [[ ${2} == "submit" ]]; then
    cd ${JDIR}
    condor_submit submit.txt
    cd ${PDIR}
fi
