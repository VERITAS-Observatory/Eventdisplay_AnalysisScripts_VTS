# select runs for BDT training
# 
# selection is based on 
# - epoch
# - observation mode
# - avoidance of strong gamma-ray sources (e.g., Crab)
#
# files are linked to a new directory
#
#

if [ $# -ne 2 ]; then
     echo "./IRF.selectRunsForBDTTraining.sh <source evndisp directory> <target evndisp directory>"
     echo 
     echo "this script has several hardwired parameters"
     exit
fi


# MAJOR EPOCH
MEPOCH="V6"
# Observing mode
OBSMODE="observing"
# Multiplicity
MULT="1234"
# Sources to avoid
BRIGHTSOURCES=( Crab Mrk421 )

echo "Reference values: ${MEPOCH} ${OBSMODE} ${MULT} ${BRIGHTSOURCES[*]} "

FLIST=$(find ${1} -name "*[0-9].mscw.log"  | sed 's/\.log$//')

mkdir -p ${2}

for F in ${FLIST}
do
    ls -1 ${F}.log
    RUNINFO=$($EVNDISPSYS/bin/printRunParameter ${F}.root -runinfo)

    TMPMEPOCH=$(echo $RUNINFO | awk '{print $2}')
    if [[ ${TMPMEPOCH} != ${MEPOCH} ]]; then
        continue
    fi
    TMPOBSMODE=$(echo $RUNINFO | awk '{print $4}')
    if [[ ${TMPOBSMODE} != ${OBSMODE} ]]; then
        continue
    fi
    TMPMULT=$(echo $RUNINFO | awk '{print $5}')
    if [[ ${TMPMULT} != ${MULT} ]]; then
        continue
    fi
    TMPTARGET=$(echo $RUNINFO | cut -d\  -f6- )
    BRK="FALSE"
    for S in ${BRIGHTSOURCES}
    do
        if [[ "${TMPTARGET}" == "${S}" ]]; then
            BRK="TRUE"
            break
        fi
    done
    if [[ $BRK == "TRUE" ]]; then
        echo "   skipping $TMPTARGET"
        continue
    fi
    echo "   found $TMPTARGET $TMPOBSMODE $TMPMEPOCH $TMPMULT"
    BNAME=$(basename ${F}.root)
    if [[ ! -e ${2}/${BNAME} ]]; then
        ln -s ${F}.root ${2}/${BNAME}
    fi
done

