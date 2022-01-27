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
$EVNDISPSYS/bin/combineEffectiveAreas "$EAFILES" $ODIR/$OFILE DL3 &> $ODIR/$OFILE.log 
bzip2 $ODIR/$OFILE.combine.log

# combine effective areas (reduced file size for anasum only)
ODIRANASUM=${ODIR}_anasum
mkdir -p $ODIRANASUM
chmod -R g+w $ODIRANASUM
$EVNDISPSYS/bin/combineEffectiveAreas "$EAFILES" ${ODIRANASUM}/$OFILE anasum &> ${ODIRANASUM}/$OFILE.log 
bzip2 ${ODIRANASUM}/$OFILE.combine.log

exit
