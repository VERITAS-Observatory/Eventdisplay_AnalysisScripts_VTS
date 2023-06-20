#!/bin/sh
#
# submit a list of scripts to HTCondor job submission system
#
# 1. submits all *.sh files in the given directory
# 2. searches for *.condor files for job submission details
# 
# note: uses largest request for job resources
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

mkdir -p ${JDIR}/log
mkdir -p ${JDIR}/output
mkdir -p ${JDIR}/error

echo "executable = \$(file)" >>  ${SUBMITF}
echo "log = log/\$(file).log" >>  ${SUBMITF}
echo "output = output/\$(file).output" >>  ${SUBMITF}
echo "error = error/\$(file).error" >>  ${SUBMITF}

# assume that all condor files have similar requests
CONDORFILE=$(find ${JDIR} -name "*.condor" | head -n 1)
echo "$(grep -h request_memory $CONDORFILE)"  >>  ${SUBMITF}
echo "$(grep -h request_disk $CONDORFILE)"  >>  ${SUBMITF}
echo "getenv = True" >>  ${SUBMITF}
echo "max_materialize = 250" >>  ${SUBMITF}
# echo "priority = 150" >> ${SUBMITF}
echo "queue file matching files *.sh" >> ${SUBMITF}

PDIR=$(pwd)
if [[ ${2} == "submit" ]]; then
    cd ${JDIR}
    condor_submit submit.txt
    cd ${PDIR}
fi
