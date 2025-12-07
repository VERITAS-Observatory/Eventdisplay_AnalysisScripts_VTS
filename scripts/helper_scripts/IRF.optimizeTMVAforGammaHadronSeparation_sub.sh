#!/bin/bash
# script to calculate signal and background rates and
# optimize BDTs with TMVA
#

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

EFFAREA=EFFFILE
PREDIR=ODIR
CUT=CUTTYPE
DEADTIME="12."
EPOCH=EEPOCH
ATM=AATM
ENBINS=EEBINS
ZEBINS=ZZBINS
TMVAPARFILES=TMVARUNPARA

if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/${CUT}
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR/${CUT}/"
fi
echo "Temporary directory: $TEMPDIR"
mkdir -p $TEMPDIR
ls -1 ${PREDIR}/${CUT}/*.anasum.root > ${TEMPDIR}/anasum.list

OBSTIME="5."
MINEVENTS="5."
if [[ $CUT == *"Moderate"* ]]; then
    OBSTIME="3.0"
elif [[ $CUT == *"Soft"* ]]; then
    OBSTIME="0.2"
elif [[ $CUT == *"Hard"* ]]; then
    OBSTIME="5."
    MINEVENTS="1."
fi

# effective area - fill path
EFFAREA="$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFAREA}"

# epoch / ATM
EPAT="${EPOCH}_ATM${ATM}"

# output directory
WDIR="${PREDIR}/Optimize-${CUT}/"
mkdir -p ${WDIR}

# rates files
RATEFILE="${WDIR}/rates_${EPAT}"

CALCULATERATEFILES="FALSE"
CALCULATERATEFILES="TRUE"
if [[ $CALCULATERATEFILES == "TRUE" ]];
then
    rm -f ${RATEFILE}.log

    # calculate rates from Crab Nebula and from background rates
    rm -f ${MVADIR}/rates.log
    "$EVNDISPSYS"/bin/calculateCrabRateFromMC \
        ${EFFAREA} \
        ${RATEFILE}.root \
        ${DEADTIME} \
        ${TMVAPARFILES} \
        ${TEMPDIR}/anasum.list \
        > ${RATEFILE}.log
fi

# optimize cuts
echo "optimize cuts..."
MVADIR="$VERITAS_EVNDISP_AUX_DIR/GammaHadronBDTs/${VERITAS_ANALYSIS_TYPE:0:2}/${EPAT}/${CUT}/"
cd ${PREDIR}/${CUT}
rm -f ${WDIR}/${EPAT}.optimised.dat
root -l -q -b "$EVNDISPSYS/macros/VTS/optimizeBDTcuts.C(\"${RATEFILE}.root\", \"$MVADIR\", \"${EPAT}\", 0, ${ENBINS}, 0, ${ZEBINS}, $OBSTIME, 5., $MINEVENTS )"  > ${WDIR}/${EPAT}.optimised.dat

exit
