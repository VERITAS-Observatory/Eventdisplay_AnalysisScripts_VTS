#!/bin/bash
# script to train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
LLIST=EVNLIST
ODIR=OUTPUTDIR
ONAME=BDTFILE
RECID="0"
TELTYPE="0"
BDT=BDTTYPE

# temporary directory
if [[ -n "$TMPDIR" ]]; then 
    DDIR="$TMPDIR/dispBDT_${BDT}/"
else
    DDIR="/tmp/dispBDT_${BDT}/"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"
# decompress
NLIST=${TMPDIR}/${ONAME}.list
FLIST=$(cat ${ODIR}/${ONAME}.list)
for F in ${FLIST}
do
    IDIR=$(dirname $F)
    OF=${TMPDIR}/$(basename $IDIR)_$(basename $F)
    cp -v -f $F ${OF}
done
find $TMPDIR -name "*.root.zst" -exec zstd -d {} \;
# TMPDIR
ls -1 $TMPDIR
ls -1 $TMPDIR/*.root > $NLIST
echo "LISTLISTLIST $NLIST"
cat $NLIST

ODIR="${ODIR}/${BDT}"
mkdir -p ${ODIR}
chmod g+w ${ODIR}
rm -f "$ODIR/$ONAME*"

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

"$EVNDISPSYS"/bin/trainTMVAforAngularReconstruction \
    ${NLIST} \
    ${DDIR} \
    "$TRAINTESTFRACTION" \
    "$RECID" \
    "$TELTYPE" \
    "${BDT}" > "$ODIR/$ONAME-$BDT.log"

cp -f ${DDIR}/${BDT}_*.root ${ODIR}/
cp -f ${DDIR}/${BDT}_*.xml ${ODIR}/
