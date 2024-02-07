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
    echo "Errors in ped files: "
    echo "--------------------"
    echo "$(grep -i error ${1}/*.ped.log)"
    echo "Errors in tzero files: "
    echo "--------------------"
    echo "$(grep -i error ${1}/*.tzero.log)"
    echo "Errors in evndisp files: "
    echo "--------------------"
    echo "$(grep -i error ${1}/*[0-9].log)"
    echo "Zero average pulse in evndisp files: "
    echo "--------------------"
    echo "$(grep "average pulse timing for this telescope is 0" ${1}/*[0-9].log)"
    echo "Warnings in evndisp files: "
    echo "--------------------"
    echo "$(grep -i warning ${1}/*[0-9].log | grep -v "warning: setlocale")"
}

if [[ $DTYPE == "evndisp" ]]; then
    check_evndisp_log_files $FDIR
fi

