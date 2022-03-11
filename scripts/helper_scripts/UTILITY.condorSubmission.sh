#!/bin/bash
# prepar a condor job submission file

if [ "$1" = "-h" ] || [ $# -ne 3 ]; then
echo "
UTILITY.condorSubmission.sh [submission script] [memory request] [disk request]

--------------------------------------------------------------------------------
"
exit
fi

SUBFIL=${1}.condor
rm -f ${SUBFIL}
echo "Executable = ${1}" > ${SUBFIL}
echo "Log = ${1}.\$(Process).log" >> ${SUBFIL}
echo "Output = ${1}.\$(Process).output" >> ${SUBFIL}
echo "Log = ${1}.\$(Process).error" >> ${SUBFIL}
echo "request_memory = ${2}" >> ${SUBFIL}
echo "request_disk = ${3}" >> ${SUBFIL}
echo "getenv = True" >> ${SUBFIL}
echo "Queue 1" >> ${SUBFIL}
