#!/bin/bash
# Error checks in log files for preprocessing
#

if [ ! -n "$2" ] || [ "$1" = "-h" ]; then
echo "
./check_runs_on_disk.sh <directory with files> <evndisp data type>

   evndisp data type can be evndisp, mscw
"
exit
fi

FDIR=${1}
DTYPE=${2}

echo "Checking runs in ${1} for data type ${DTYPE}"

check_evndisp_log_files()
{
    # check number of log files of all stages
    PNLOG=$(ls -1 ${1}/*.ped.log | wc -l)
    TNLOG=$(ls -1 ${1}/*.tzero.log | wc -l)
    ANLOG=$(ls -1 ${1}/*[0-9].log | wc -l)
    echo "Number of log files: ped $PNLOG tzero $TNLOG evndisp $ANLOG"
    echo "Ped files: "
    echo "--------------------"
    echo "   Container revisions: $(grep -h org.opencontainers.image.revision ${1}/*.ped.log | sort -u)"
    echo "$(grep -i error ${1}/*.ped.log)"
    echo "Tzero files: "
    echo "--------------------"
    echo "   Container revisions: $(grep -h org.opencontainers.image.revision ${1}/*.tzero.log | sort -u)"
    echo "$(grep -i error ${1}/*.tzero.log)"
    echo "Evndisp files: "
    echo "--------------------"
    echo "   Container revisions: $(grep -h org.opencontainers.image.revision ${1}/*[0-9].log | sort -u)"
    echo "$(grep -i error ${1}/*[0-9].log)"
    echo "Zero average pulse in evndisp files: "
    echo "--------------------"
    echo "$(grep "average pulse timing for this telescope is 0" ${1}/*[0-9].log)"
    echo "Warnings in evndisp files: "
    echo "--------------------"
    echo "$(grep -i warning ${1}/*[0-9].log | grep -v "WARNING: Skipping mount")"
    grep -h -i EVNDISP.reconstruction.runparameter ${1}/*[0-9].log  | tee -a $TMPLOG
}

check_mscw_log_files()
{
    NFIL=$(ls -1 ${1}/*.mscw.root | wc -l)
    echo "Number of mscw file: $NFIL"
    echo "Container revisions: $(grep -h org.opencontainers.image.revision ${1}/*.mscw.log | sort -u)"
    echo "Errors in mscw log files:"
    echo "$(grep -i error ${1}/*.mscw.log |  grep -v "error weighting parameter" | grep -v BDTDispError | grep -v "disp error")"
    grep -h -i "lookuptable:" ${1}/*[0-9].mscw.log > $TMPLOG
}

TMPLOG="$(pwd)/DQM.${DTYPE}.$(uuid).tmp.txt"
rm -f $TMPLOG
if [[ $DTYPE == "evndisp" ]]; then
    check_evndisp_log_files $FDIR
    cat $TMPLOG | sort -u
elif [[ $DTYPE == "mscw" ]]; then
    check_mscw_log_files $FDIR
    cat $TMPLOG | sort -u
fi
rm -f $TMPLOG
