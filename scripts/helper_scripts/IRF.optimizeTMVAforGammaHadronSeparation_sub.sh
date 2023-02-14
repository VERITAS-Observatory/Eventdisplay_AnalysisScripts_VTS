#!/bin/bash
# script to calcualte signal and background rates and
# optimize BDTs with TMVA
#

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

EFFAREA=EFFFILE
PREDIR=ODIR
CUT=CUTTYPE
ETHRESH="1."
EPOCH=EEPOCH
ATM=AATM
ENBINS=EEBINS
ZEBINS=ZZBINS

if [[ -n $TMPDIR ]]; then
    TEMPDIR=$TMPDIR/${CUT}
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR/${CUT}/"
fi
echo "Temporary directory: $TEMPDIR"
mkdir -p $TEMPDIR
ls -1 ${PREDIR}/${CUT}/*.anasum.root > ${TEMPDIR}/anasum.list

# effective area - fill path
EFFAREA="$VERITAS_EVNDISP_AUX_DIR/EffectiveAreas/${EFFAREA}"

# epoch / ATM
EPAT="${EPOCH}_ATM${ATM}"

# output directory
WDIR="${PREDIR}/Optimize-${CUT}/"
mkdir -p ${WDIR}

# rates files
RATEFILE="${WDIR}/rates_${EPAT}"

rm -f ${RATEFILE}.log

# calculate rates from Crab Nebula and from background rates
rm -f ${MVADIR}/rates.log
"$EVNDISPSYS"/bin/calculateCrabRateFromMC \
    ${EFFAREA} \
    ${RATEFILE}.root \
    ${ETHRESH} \
    ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/TMVA.BDT.runparameter \
    ${TEMPDIR}/anasum.list \
    > ${RATEFILE}.log

# optimize cuts
echo "optimize cuts..."
MVADIR="$VERITAS_EVNDISP_AUX_DIR/GammaHadron_BDTs/${EPAT}/${CUT}/"
cd ${PREDIR}/${CUT}
rm -f ${WDIR}/${EPAT}.optimised.dat
root -l -q -b "$EVNDISPSYS/macros/VTS/optimizeBDTcuts.C(\"${RATEFILE}.root\", \"$MVADIR\", \"${EPAT}\", 0, ${ENBINS}, 0, ${ZEBINS})"  > ${WDIR}/${EPAT}.optimised.dat

exit
