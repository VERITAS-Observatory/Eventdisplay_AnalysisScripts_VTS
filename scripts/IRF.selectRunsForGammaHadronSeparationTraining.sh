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

echo "Reference values: ${MEPOCH} ${OBSMODE}"
echo "Multiplicity cut: ${MULT}"
echo "Minimum observing time: ${MINOBSTIME} s"
echo "Avoiding bright sources: ${BRIGHTSOURCES[*]}"

# zenith angle bins
if [[ "${RUNPAR##*.}" == "json" ]]; then
    echo "Reading zenith bins from json file"
    ZEBIN_EDGES=$(jq -r '.zenith_bins_deg[] | "\(.Ze_min) \(.Ze_max)"' "$RUNPAR" | awk '{print $1}')
    ZEBIN_MAX=$(jq -r '.zenith_bins_deg[-1].Ze_max' "$RUNPAR")

    # Combine into a single space-separated string of unique bin edges
    ZEBINS=$(echo "$ZEBIN_EDGES" "$ZEBIN_MAX" | tr '\n' ' ' | awk '{
        # Store unique values in order
        split($0, arr);
        prev = "";
        for (i in arr) {
            if (arr[i] != prev) {
                printf "%s ", arr[i];
                prev = arr[i];
            }
        }
    }')
else
    ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
fi
echo "Zenith angle definition: $ZEBINS"
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-1)) #get number of bins

if [[ $MEPOCH == "V4" ]]; then
    FLIST=$(find ${2} -name "[3,4]*[0-9].mscw.root"  | sed 's/\.root$//')
elif [[ $MEPOCH == "V5" ]]; then
    FLIST=$(find ${2} -name "[4,5,6]*[0-9].mscw.root"  | sed 's/\.root$//')
else
    FLIST=$(find "$2" -regextype posix-extended \
      -regex '.*/(6|7|8|9|1[0-5])[0-9]*\.mscw\.root' \
      | sed 's/\.root$//')
fi

echo $FLIST
exit

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
    RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${F}.root -runinfo)
    echo "   RUNINFO $RUNINFO"

    RUNZENITH=$(echo $RUNINFO | awk '{print $8}')
    ZEBIN=0
    for (( j=0; j < $NZEW; j++ ))
    do
        if [[ ${RUNZENITH} > ${ZEBINARRAY[$j]} ]] && [[ ${RUNZENITH} < ${ZEBINARRAY[$j+1]} ]]; then
            ZEBIN=$j
            break;
        fi
    done
    echo "   Zenith bin: ${ZEBIN} for zenith angle ${RUNZENITH}"

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
    RUNWOBBLE=$(echo "$RUNINFO" | awk '{print $10}')
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
