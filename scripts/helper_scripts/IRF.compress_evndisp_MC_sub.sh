#!/bin/bash
# script put log files into evndisp file and compress output

# set observatory environmental variables
source "$EVNDISPSYS"/setObservatory.sh VTS

ONAME=RUNNUMBER
ODIR=OUTPUTDIR

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/testDir"
else
    DDIR="/tmp/testDir"
fi
mkdir -p $DDIR

compare_log_file()
{
    $EVNDISPSYS/bin/logFile $1 $ODIR/$ONAME.root > ${DDIR}/${1}.log
    if cmp -s "${2}" "${DDIR}/${1}.log"; then
        echo "FILES ${1} ${2} are the same, removing"
        touch ${2}.good
    else
        echo "Error, ${1} ${2} differ"
    fi
}

add_log_file()
{
     # first check if logFile is already included in evndisp file
     LCON=$($EVNDISPSYS/bin/logFile $1 $ODIR/$ONAME.root | grep "Error: log file object" | wc -l)
     if [[ ${LCON} == 1 ]]; then
         echo "writing log file ${2}"
         if [[ -f ${2} ]]; then
             $EVNDISPSYS/bin/logFile $1 $ODIR/$ONAME.root ${2}
         fi
     else
         echo "log file ${2} already in $ODIR/$ONAME.root"
     fi
}

echo "EVNDISP output root file $ODIR/$ONAME.root"

### add log files to evndisp file
add_log_file evndispLog $ODIR/$ONAME.log
add_log_file evndisppedLog $ODIR/$ONAME.ped.log
add_log_file evndisptzeroLog $ODIR/$ONAME.tzero.log

### check that log files are filled correctly
compare_log_file evndispLog $ODIR/$ONAME.log
compare_log_file evndisppedLog $ODIR/$ONAME.ped.log
compare_log_file evndisptzeroLog $ODIR/$ONAME.tzero.log

### compress
if command -v zstd /dev/null; then
    if [[ ! -f $ODIR/$ONAME.root.zst ]]; then
        zstd $ODIR/$ONAME.root
    else
        echo "No compression, $ODIR/$ONAME.root.zst exists"
    fi
    zstd --test $ODIR/$ONAME.root.zst
else
    echo "Error: zstd compressing executable not found"
fi

exit
