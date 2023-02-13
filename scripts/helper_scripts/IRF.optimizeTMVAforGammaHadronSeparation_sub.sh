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

# calculate rates from Crab Nebula and from background rates
rm -f ${MVADIR}/rates.log
"$EVNDISPSYS"/bin/calculateCrabRateFromMC \
    ${EFFAREA} \
    ${PREDIR}/${CUT}/rates_${EPOCH}_ATM${ATM}.root \
    ${ETHRESH} \
    ${VERITAS_EVNDISP_AUX_DIR}/ParameterFiles/TMVA.BDT.runparameter \
    ${TEMPDIR}/anasum.list  > "${PREDIR}/${CUT}/rates_${EPOCH}_ATM${ATM}.log"

# optimize cuts
echo "optimize cuts..."
MVADIR="$VERITAS_EVNDISP_AUX_DIR/GammaHadron_BDTs/${EPOCH}_ATM${ATM}/${CUT}/"
cd ${PREDIR}/${CUT}
rm -f ${PREDIR}/${CUT}/${CUT}.optimised.dat
root -l -q -b "$EVNDISPSYS/macros/VTS/optimizeBDTcuts.C(\"rates_${EPOCH}_ATM${ATM}.root\", \"$MVADIR\", 0, ${ENBINS}, 0, ${ZEBINS})" > ${PREDIR}/${CUT}/${CUT}_${EPOCH}_ATM${ATM}.optimised.dat

exit
