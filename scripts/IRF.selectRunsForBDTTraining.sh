# select mscw files for BDT training
# 
# selection is based on 
# - epoch
# - observation mode
# - avoidance of strong gamma-ray sources (e.g., Crab)
#
# files are linked to a new directory
#
#

if [ $# -ne 3 ]; then
     echo "./IRF.selectRunsForBDTTraining.sh <source mscw directory> <target mscw directory> <TMVA run parameter file>"
     echo 
     echo "files are sorted in zenith angle bins defined in TMVA run parameter file"
     echo "this script has several hardwired parameters"
     exit
fi

TARGETDIR="${2}"
RUNPAR="${3}"

# MAJOR EPOCH
MEPOCH="V6"
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

FLIST=$(find ${1} -name "*[0-9].mscw.log"  | sed 's/\.log$//')

mkdir -p ${2}

linkFile()
{
    mkdir -p $(dirname "$1")
    if [[ ! -e "$1" ]]; then
        ln -s "$2" "$1"
    fi
}


for F in ${FLIST}
do
    ls -1 ${F}.log
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
    TMPTARGET=$(echo $RUNINFO | cut -d\  -f7- )
    echo "TARGET $TMPTARGET"
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
    echo "   found $TMPTARGET $TMPOBSMODE $TMPMEPOCH $MINOREPOCH $TMPMULT $TMPOBSTIME $RUNZENITH (ZE bin ${ZEBIN})"
    BNAME=$(basename ${F}.root)

    ## linking
    linkFile ${TARGETDIR}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/Ze_${ZEBIN}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/${MINOREPOCH}/${BNAME} ${F}.root
    linkFile ${TARGETDIR}/${MINOREPOCH}/Ze_${ZEBIN}/${BNAME} ${F}.root
done
