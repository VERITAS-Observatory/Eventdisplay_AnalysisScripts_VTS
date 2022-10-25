#!/bin/bash
# prepare a condor job submission file

if [ "$1" = "-h" ]; then
echo "
UTILITY.condorSubmission.sh [submission script] [memory request] [disk request] <optional: array jobs>

--------------------------------------------------------------------------------
"
exit
fi

SUBFIL=${1}.condor
rm -f ${SUBFIL}
echo "JobBatchName = ${1}" > ${SUBFIL}
echo "Executable = ${1}" > ${SUBFIL}
echo "Log = ${1}.\$(Cluster)_\$(Process).log" >> ${SUBFIL}
echo "Output = ${1}.\$(Cluster)_\$(Process).output" >> ${SUBFIL}
echo "Error = ${1}.\$(Cluster)_\$(Process).error" >> ${SUBFIL}
echo "Log = ${1}.\$(Cluster)_\$(Process).log" >> ${SUBFIL}
echo "request_memory = ${2}" >> ${SUBFIL}
echo "request_disk = ${3}" >> ${SUBFIL}
echo "getenv = True" >> ${SUBFIL}
echo "max_materialize = 50" >> ${SUBFIL}
if [ ! -z "$4" ]; then
    echo "queue ${4}" >> ${SUBFIL}
else
    echo "queue 1" >> ${SUBFIL}
fi
