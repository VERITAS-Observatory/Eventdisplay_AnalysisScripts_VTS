#!/bin/bash
# prepare a condor job submission file

if [ "$1" = "-h" ]; then
echo "
UTILITY.condorSubmission.sh [submission script] [memory request] [disk request]

--------------------------------------------------------------------------------
"
exit
fi

SUBSCRIPT=$(readlink -f "${1}")
SUBFIL=${SUBSCRIPT}.condor

[[ -f "$SUBFIL" ]] && rm -f "$SUBFIL".

cat > ${SUBFIL} <<EOL
Executable = ${SUBSCRIPT}
Output = ${SUBSCRIPT}.\$(Cluster)_\$(Process).output
Error = ${SUBSCRIPT}.\$(Cluster)_\$(Process).error
Log = ${SUBSCRIPT}.\$(Cluster)_\$(Process).log
request_memory = ${2}
request_disk = ${3}
getenv = True
max_materialize = 50
priority = 850
queue 1
EOL
