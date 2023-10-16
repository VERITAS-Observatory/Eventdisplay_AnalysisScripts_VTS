#!/bin/bash
# script to link pre-processed anasum files to an anasum output directory

EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`

if [[ $# -lt 3 ]]; then
# begin help message
echo "
ANASUM analysis preparation: link pre-processed files to output directory

./ANALYSIS.anasum_link_files.sh <anasum run list> <anasum directory> <output directory>

required parameters:

    <anasum run list>       short run list (run numbers only)
        
    <anasum directory>      input directory containing anasum root files
                            (usually directory with pre-processed files)

    <output directory>      directory with links to pre-processed files
        
--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RUNLIST=$1
DDIR=$2
ODIR=$3

# Check that run list exists
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, anasum runlist $RUNLIST not found, exiting..."
    exit 1
fi

# output directory
mkdir -p ${ODIR}
# directory schema
getNumberedDirectory()
{
    TRUN="$1"
    IDIR="$2"
    if [[ ${TRUN} -lt 100000 ]]; then
        NDIR="${IDIR}/${TRUN:0:1}/"
    else
        NDIR="${IDIR}/${TRUN:0:2}/"
    fi
    echo ${NDIR}
}

RUNS=`cat "$RUNLIST"`
NRUNS=`cat "$RUNLIST" | wc -l `
echo "total number of runs to be linked: $NRUNS"

for RUN in ${RUNS[@]}; do
    ARCHIVEDIR=$(getNumberedDirectory $RUN $DDIR)
    if [ -e "${ARCHIVEDIR}/${RUN}.anasum.root" ]; then
        ls ${ARCHIVEDIR}/${RUN}.anasum.root
        ln -f -s ${ARCHIVEDIR}/${RUN}.anasum.root ${ODIR}/${RUN}.anasum.root
    fi
done

