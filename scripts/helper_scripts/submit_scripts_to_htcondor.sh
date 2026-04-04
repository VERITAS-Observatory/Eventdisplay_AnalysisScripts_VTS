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
    ./submit_scripts_to_htcondor.sh <job directory> [submit/nosubmit] [priority]

    "
    exit
fi

JDIR=${1}
PRIORITY="${3:-1}"

echo "Writing HTCondor job submission file ${SUBMITF} (job priority $PRIORITY) for ${JDIR}"
if find "${JDIR}" -name "*.condor" -print -quit | grep -q .; then
    SUBMITF=${1}/submit.txt
    rm -f ${SUBMITF}
    touch ${SUBMITF}

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
    echo "max_materialize = 1800" >>  ${SUBMITF}
#    echo "request_cpus = 8" >>  ${SUBMITF}
    echo "priority = $PRIORITY"  >> ${SUBMITF}
    echo "queue file matching files *.sh" >> ${SUBMITF}

    PDIR=$(pwd)
    if [[ ${2} == "submit" ]]; then
        cd ${JDIR}
        condor_submit submit.txt requirements='OpSysAndVer=="AlmaLinux9"'
        cd ${PDIR}
    fi
else
    echo "Error: no condor files found in ${JDIR}"
fi
