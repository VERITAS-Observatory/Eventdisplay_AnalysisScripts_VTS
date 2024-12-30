#!/bin/bash
# select mscw files for BDT gamma/hadron separation training
#
# selection is based on
# - epoch
# - observation mode
# - avoidance of strong gamma-ray sources (e.g., Crab)
#
# files are linked to a new directory
#

if [ $# -ne 4 ]; then
    echo "./IRF.selectRunsForGammaHadronSeparationTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file (full path)>"
     echo
     echo "files are sorted in epochs, observations mode, zenith angle bins defined in TMVA run parameter file"
     echo "this script has several hardwired parameters"
     exit
fi

MEPOCH="${1}"
TARGETDIR="${3}"
RUNPAR="${4}"

# Observing mode
OBSMODE="observing"
# Multiplicity
MULT="1234"
# Skip runs shorter than this time (s)
# (require a 10 min run)
MINOBSTIME=600
# Sources to avoid
BRIGHTSOURCES=( Crab Mrk421 )

echo "Reference values: ${MEPOCH} ${OBSMODE} ${MULT} ${BRIGHTSOURCES[*]} "

# zenith angle bins
ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
echo "Zenith angle definition: $ZEBINS"
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-1)) #get number of bins

if [[ $MEPOCH == "V4" ]]; then
    FLIST=$(find ${2} -name "[3,4]*[0-9].mscw.root"  | sed 's/\.root$//')
elif [[ $MEPOCH == "V5" ]]; then
    FLIST=$(find ${2} -name "[4,5,6]*[0-9].mscw.root"  | sed 's/\.root$//')
else
    FLIST=$(find ${2} -name "[6-9, 10]*[0-9].mscw.root"  | sed 's/\.root$//')
fi

mkdir -p ${3}

linkFile()
{
    mkdir -p $(dirname "$1")
    if [[ ! -e "$1" ]]; then
        ln -s "$2" "$1"
    fi
}


for F in ${FLIST}
do
    echo "LINKING file ${F}.root"
    BNAME=$(basename ${F}.root)
    if [[ -e ${TARGETDIR}/${BNAME} ]]; then
        echo "    found..."
        continue
    fi
    RUNZENITH=$($EVNDISPSYS/bin/printRunParameter ${F}.root -zenith | awk '{print $4}')
    ZEBIN=0
    for (( j=0; j < $NZEW; j++ ))
    do
        if [[ ${RUNZENITH} > ${ZEBINARRAY[$j]} ]] && [[ ${RUNZENITH} < ${ZEBINARRAY[$j+1]} ]]; then
            ZEBIN=$j
            break;
        fi
    done
    echo "   Zenith bin: ${ZEBIN}"
    RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${F}.root -runinfo)
    echo "   RUNINFO $RUNINFO"

    TMPMEPOCH=$(echo $RUNINFO | awk '{print $2}')
    if [[ ${TMPMEPOCH} != ${MEPOCH} ]]; then
        continue
    fi
    MINOREPOCH=$(echo $RUNINFO | awk '{print $1}')
    TMPOBSMODE=$(echo $RUNINFO | awk '{print $4}')
    if [[ ${TMPOBSMODE} != ${OBSMODE} ]]; then
        echo "   SKIPPING OBSMODE: ${TMPOBSMODE} ${OBSMODE}"
        continue
    fi
    TMPMULT=$(echo $RUNINFO | awk '{print $5}')
    if [[ ${TMPMULT} != ${MULT} ]]; then
        echo "   SKIPPING MULT ${TMPMULT} ${MULT}"
        continue
    fi
    TMPOBSTIME=$(echo $RUNINFO | awk '{print $6}')
    if (( $TMPOBSTIME <  $MINOBSTIME )); then
        echo "   SKIPPING OBSTIME: $TMPOBSTIME $MINOBSTIME"
        continue
    fi
    # need to take care of target with spaces in their names
    TMPTARGET=$(echo "$RUNINFO" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | awk '{$1=$1;print}')
    echo "   TARGET $TMPTARGET"
    BRK="FALSE"
    for (( l=0; l < ${#BRIGHTSOURCES[@]}; l++ ))
    do
        if [[ "${TMPTARGET}" == "${BRIGHTSOURCES[$l]}" ]]; then
            BRK="TRUE"
            break
        fi
    done
    if [[ $BRK == "TRUE" ]]; then
        echo "   SKIPPING $TMPTARGET"
        continue
    fi
    # ignore runs with zero wobble offsets
    RUNWOBBLE=$($EVNDISPSYS/bin/printRunParameter ${F}.root -wobbleInt | awk '{print $3}')
    if [[ $RUNWOBBLE == "0" ]]; then
        echo "   SKIPPING WOBBLE $RUNWOBBLE"
        continue
    fi
    echo "   found $TMPTARGET $TMPOBSMODE $TMPMEPOCH $MINOREPOCH $TMPMULT $TMPOBSTIME $RUNZENITH (ZE bin ${ZEBIN}, W ${RUNWOBBLE})"
    BNAME=$(basename ${F}.root)

    ## linking
    linkFile ${TARGETDIR}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/Ze_${ZEBIN}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/${MINOREPOCH}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/${MINOREPOCH}/Ze_${ZEBIN}/${BNAME} ${F}.root
done
