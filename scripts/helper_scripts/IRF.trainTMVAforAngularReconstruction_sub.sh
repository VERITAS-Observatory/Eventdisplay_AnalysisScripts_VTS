#!/bin/bash
# train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
LLIST=EVNLIST
IRFVERSION=VERSIONIRF
ODIR=OUTPUTDIR
ONAME=BDTFILE
RECID="RRECID"
TELTYPE="TTYPE"
BDT=BDTTYPE
TMVAO=TMVAOPTIONFILE

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/dispBDT_${BDT}/"
else
    DDIR="/tmp/dispBDT_${BDT}/"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:${DDIR}"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=${DDIR},CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
    CALDIR="/opt/ODIR"
fi

# decompress
NLIST=${ONAME}.list
echo $NLIST
for F in $(cat $LLIST)
do
    IDIR=$(dirname $F)
    OF=${DDIR}/$(basename $IDIR)_$(basename $F)
    cp -v -f $F ${OF}
done
find $DDIR -name "*.root.zst" -exec zstd -f -d {} \;
ls -1 $DDIR
ls -1 $DDIR/*.root > ${DDIR}/$NLIST
echo "FILELIST ${DDIR}/$NLIST"
cat ${DDIR}/$NLIST

ODIR="${ODIR}/${BDT}"
mkdir -p ${ODIR}
chmod g+w ${ODIR}
rm -f "$ODIR/$ONAME*"

if [[ $IRFVERSION != v490* ]]; then
    # TMVA options
    TMVAOPTIONS="$(grep 'MVAOPTIONS' $TMVAO | awk '{print $3}')"
    # quality cuts
    QUALITYCUTS="$(grep 'MVAQUALITYCUTS' $TMVAO | awk '{print $3}')"
else
    TMVAOPTIONS=""
    QUALITYCUTS=""
fi

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

# per event weight (use carefully)
# EWEIGHT="sqrt(MCe0/0.5)"
# EWEIGHT="10.*(1.+loss)"
EWEIGHT=""

$EVNDISPSYS/bin/trainTMVAforAngularReconstruction \
    "${DDIR}/${NLIST}" \
    "${DDIR}" \
    "$TRAINTESTFRACTION" \
    "$RECID" \
    "$TELTYPE" \
    "${BDT}" \
    "${QUALITYCUTS}" \
    "${TMVAOPTIONS}" \
    "${EWEIGHT}" > "$ODIR/$ONAME-$BDT.log"

cp -f ${DDIR}/${BDT}_*.root ${ODIR}/
cp -f ${DDIR}/${BDT}_*.xml ${ODIR}/
# (potentially large training file)
cp -v ${DDIR}/BDTDisp.root ${ODIR}/
