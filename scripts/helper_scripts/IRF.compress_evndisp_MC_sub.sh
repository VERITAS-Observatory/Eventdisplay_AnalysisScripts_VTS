#!/bin/bash
# script put log files into evndisp file and compress output

# set observatory environmental variables
source "$EVNDISPSYS"/setObservatory.sh VTS

ONAME=RUNNUMBER
IDIR=INPUTDIR
ODIR=OUTPUTDIR

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/testDir"
else
    DDIR="/tmp/testDir"
fi
mkdir -p $DDIR
mkdir -p $ODIR

compare_log_file()
{
    $EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root > ${DDIR}/${1}.log
    if cmp -s "${2}" "${DDIR}/${1}.log"; then
        echo "FILES ${1} ${2} are the same, removing"
        touch $ODIR/$ONAME.${1}.goodlog
    else
        echo "Error, ${1} ${2} differ"
        touch $ODIR/$ONAME.${1}.errorlog
    fi
}

add_log_file()
{
     # first check if logFile is already included in evndisp file
     LCON=$($EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root | grep "Error: log file object" | wc -l)
     if [[ ${LCON} == 1 ]]; then
         echo "writing log file ${2}"
         if [[ -f ${2} ]]; then
             $EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root ${2}
         fi
     else
         echo "log file ${2} already in $DDIR/$ONAME.root"
     fi
}

echo "EVNDISP input root file $IDIR/$ONAME.root"
echo "EVNDISP output root file $ODIR/$ONAME.root.zst"
cp -v $IDIR/$ONAME.root ${DDIR}/

### add log files to evndisp file
add_log_file evndispLog $IDIR/$ONAME.log
add_log_file evndisppedLog $IDIR/$ONAME.ped.log
add_log_file evndisptzeroLog $IDIR/$ONAME.tzero.log

### check that log files are filled correctly
compare_log_file evndispLog $IDIR/$ONAME.log
compare_log_file evndisppedLog $IDIR/$ONAME.ped.log
compare_log_file evndisptzeroLog $IDIR/$ONAME.tzero.log

### compress
if command -v zstd /dev/null; then
    zstd $DDIR/$ONAME.root
    zstd --test $DDIR/$ONAME.root.zst
    mv -f -v $DDIR/$ONAME.root.zst ${ODIR}/
else
    echo "Error: zstd compressing executable not found"
fi

exit
