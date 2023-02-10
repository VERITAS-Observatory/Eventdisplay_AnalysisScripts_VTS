#!/bin/bash
# prepare a condor job submission file

if [ "$1" = "-h" ]; then
echo "
UTILITY.condorSubmission.sh [submission script] [memory request] [disk request] <optional: array jobs>

--------------------------------------------------------------------------------
"
exit
fi

SUBSCRIPT=$(readlink -f ${1})
SUBFIL=${SUBSCRIPT}.condor

rm -f ${SUBFIL}
echo "JobBatchName = ${SUBSCRIPT}" > ${SUBFIL}
echo "Executable = ${SUBSCRIPT}" > ${SUBFIL}
echo "Log = ${SUBSCRIPT}.\$(Cluster)_\$(Process).log" >> ${SUBFIL}
echo "Output = ${SUBSCRIPT}.\$(Cluster)_\$(Process).output" >> ${SUBFIL}
echo "Error = ${SUBSCRIPT}.\$(Cluster)_\$(Process).error" >> ${SUBFIL}
echo "Log = ${SUBSCRIPT}.\$(Cluster)_\$(Process).log" >> ${SUBFIL}
echo "request_memory = ${2}" >> ${SUBFIL}
echo "request_disk = ${3}" >> ${SUBFIL}
echo "getenv = True" >> ${SUBFIL}
echo "max_materialize = 50" >> ${SUBFIL}
# allow to prioritize jobs
# echo "priority = 15" >> ${SUBFIL}
if [ ! -z "$4" ]; then
    echo "queue ${4}" >> ${SUBFIL}
else
    echo "queue 1" >> ${SUBFIL}
fi
