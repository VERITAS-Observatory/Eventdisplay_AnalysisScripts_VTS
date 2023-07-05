#!/bin/bash
# check a run list for runs not to be processed
# and remove corresponding data products
#
#
#
if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
Remove runs.* listed in a simple run list.
Used to cleanup directories during preprocessing.

./remove_runs_ignored_from_list.sh <list of runs to be removed> <directory of data files>

WARNING! This removes files.
"
exit
fi

RUNLIST=${1}
DDIR=${2}
[[ "$3" ]] && REMOVEFILES=$1 || REMOVEFILES="FALSE"


RLIST=$(cut -f1 -d' ' ${RUNLIST})

for R in $RLIST
do
    if [[ $REMOVEFILES = "FALSE" ]]; then
        echo "Really remove $DDIR/$R*?"
    else
        rm -f -v $DDIR/$R*
    fi
done
