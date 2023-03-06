#!/bin/bash
# sort and move files with file names [runnumber].*suffix
# into subdirectories starting with the first (two) digits
# of the run number.
# This lowers significantly the number of files in a directory
# 

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
# begin help message
echo "
Sort and move files into numbered directories

./UTILITY.sortRunsInSubDirectories.sh <directory> <file suffix> <target directory>

--------------------------------------------------------------------------------
"
#end help message
exit
fi

DDIR="${1}"
SUFF="${2}"
TDIR="${3}"

getNumberedDirectory()
{
    TRUN="$1"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${TDIR}/${TRUN:0:1}/"
    else
        ODIR="${TDIR}/${TRUN:0:2}/"
    fi
    mkdir -p ${ODIR}
    echo ${ODIR}
}

FLIST=$(find ${DDIR} -name [0-9]*.*${SUFF})

for F in ${FLIST}
do
    RUNN=$(basename ${F})
    RUNN="${RUNN%%.*}"
    ODIR=$(getNumberedDirectory $RUNN)
    mv -f -v ${F} ${ODIR}
done
