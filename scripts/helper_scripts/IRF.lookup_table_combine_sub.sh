#!/bin/bash
# combine tables

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
FLIST=TABLELIST
OFILE=OUTPUTFILE
ODIR=OUTPUTDIR

# combine the tables
if [[ $IRFVERSION = "v4"* ]]; then
    $EVNDISPSYS/bin/combineLookupTables $ODIR/$FLIST $ODIR/$OFILE.root median &> $ODIR/$OFILE.log 
else
    $EVNDISPSYS/bin/combineLookupTables $ODIR/$FLIST $ODIR/$OFILE.root &> $ODIR/$OFILE.log 
fi
$EVNDISPSYS/bin/logFile makeTableCombineLog $ODIR/$OFILE.root $ODIR/$OFILE.log
$EVNDISPSYS/bin/logFile makeTableFileList $ODIR/$OFILE.root $ODIR/$FLIST

# smooth lookup tables (not v4xx)
# IRFVERSION=`$EVNDISPSYS/bin/combineLookupTables --version | tr -d .| sed -e 's/[a-Z]*$//'`
# if [[ $IRFVERSION = "v4"* ]]; then
#    echo "no smoothing in version $IRFVERSION"
# else
#    "$EVNDISPSYS"/bin/smoothLookupTables "$ODIR/$OFILE.root" "$ODIR/$OFILE-smoothed.root" &> "$ODIR/$OFILE-smoothed.log"
# fi

exit
