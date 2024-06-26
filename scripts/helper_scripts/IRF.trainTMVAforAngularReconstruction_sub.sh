#!/bin/bash
# script to train TMVA (BDTs) for angular reconstruction

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

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

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT+=" --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT+=" --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT+=" --bind ${DDIR}:/opt/DDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=/opt/DDIR,CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
    CALDIR="/opt/ODIR"
fi

# decompress
NLIST=${ONAME}.list
FLIST=$(cat ${ODIR}/${ONAME}.list)
for F in ${FLIST}
do
    IDIR=$(dirname $F)
    OF=${DDIR}/$(basename $IDIR)_$(basename $F)
    cp -v -f $F ${OF}
done
find $DDIR -name "*.root.zst" -exec zstd -f -d {} \;
ls -1 $DDIR
ls -1 $DDIR/*.root > ${DDIR}/$NLIST
echo "LISTLISTLIST ${DDIR}/$NLIST"
cat ${DDIR}/$NLIST

ODIR="${ODIR}/${BDT}"
mkdir -p ${ODIR}
chmod g+w ${ODIR}
rm -f "$ODIR/$ONAME*"

# quality cuts
QUALITYCUTS="size>1.&&ntubes>log10(4.)&&width>0.&&width<2.&&length>0.&&length<10.&&tgrad_x<100.*100.&&loss<0.20&&cross<20.0&&Rcore<2000."

# TMP loose quality cuts
QUALITYCUTS="size>1.&&ntubes>log10(4.)&&width>0.&&width<2.&&length>0.&&length<10.&&tgrad_x<100.*100.&&loss<0.40&&cross<20.0&&Rcore<2000."
QUALITYCUTS="size>1.&&ntubes>log10(4.)&&width>0.&&width<2.&&length>0.&&length<10.&&tgrad_x<100.*100.&&loss<0.20&&cross<20.0&&Rcore<2000."

# fraction of events to use for training,
# remaining events will be used for testing
TRAINTESTFRACTION=0.5

$EVNDISPSYS/bin/trainTMVAforAngularReconstruction \
    "${DDIR}/${NLIST}" \
    "${DDIR}" \
    "$TRAINTESTFRACTION" \
    "$RECID" \
    "$TELTYPE" \
    "${BDT}" \
    "${QUALITYCUTS}" > "$ODIR/$ONAME-$BDT.log"

cp -f ${DDIR}/${BDT}_*.root ${ODIR}/
cp -f ${DDIR}/${BDT}_*.xml ${ODIR}/
