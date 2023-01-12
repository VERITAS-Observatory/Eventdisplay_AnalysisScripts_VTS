#!/bin/bash
# script to train BDTs with TMVA

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
RXPAR=RUNPARAM
          
"$EVNDISPSYS"/bin/trainTMVAforGammaHadronSeparation "$RXPAR".runparameter > "$RXPAR".log

# remove unnecessary *.C files
CDIR=`dirname $RXPAR`
rm -f -v "$CDIR"/$ONAME*.C

exit
