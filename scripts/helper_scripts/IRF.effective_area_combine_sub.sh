#!/bin/bash
# script to combine effective areas twice:
# - for DL3 analysis (large file size)
# - for anasum analysis (small file size)

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
EAFILES=INPUTFILES
OFILE=OUTPUTFILE
ODIR=OUTPUTDIR
mkdir -p $ODIR
chmod -R g+w $ODIR

# keep a list of all input files for checks
rm -f $ODIR/$OFILE.list
ls -1 $EAFILES > $ODIR/$OFILE.list

# combine effective areas (for DL3)
$EVNDISPSYS/bin/combineEffectiveAreas "$ODIR/$OFILE.list" $ODIR/$OFILE DL3 &> $ODIR/$OFILE.log 
bzip2 $ODIR/$OFILE.combine.log

# combine effective areas (reduced file size for anasum only)
ODIRANASUM=${ODIR}_anasum
mkdir -p $ODIRANASUM
chmod -R g+w $ODIRANASUM
$EVNDISPSYS/bin/combineEffectiveAreas "$ODIR/$OFILE.list" ${ODIRANASUM}/$OFILE anasum &> ${ODIRANASUM}/$OFILE.log 
bzip2 ${ODIRANASUM}/$OFILE.combine.log

# combine effective areas (reduced file size with TH2F replaced by arrays)
ODIRDL3array=${ODIR}_DL3array
mkdir -p $ODIRDL3array
chmod -R g+w $ODIRDL3array
$EVNDISPSYS/bin/combineEffectiveAreas "$ODIR/$OFILE.list" ${ODIRDL3array}/$OFILE DL3reduced &> ${ODIRDL3array}/$OFILE.log 
bzip2 ${ODIRDL3array}/$OFILE.combine.log

exit
