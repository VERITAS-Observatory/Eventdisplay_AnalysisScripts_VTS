#!/bin/bash
# script to calculate effective areas (VERITAS)

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
OFILE=EAFILENAME
MCFILE=DATAFILE
ODIR=OUTPUTDIR
CUTSLIST="GAMMACUTS"
EFFAREAFILE=EFFFILE
DISPBDT=USEDISP

# temporary directory
if [[ -n "$TMPDIR" ]]; then 
    DDIR="$TMPDIR/EFFAREA/"
else
    DDIR="/tmp/EFFAREA"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"

# cp MC file to TMPDIR
cp -f "$MCFILE" "$DDIR"/
MCFILE=`basename $MCFILE`
MCFILE=${DDIR}/${MCFILE}

# loop over all cuts
for CUTSFILE in $CUTSLIST; do

# Check that cuts file exists
    CUTSFILE=${CUTSFILE%%.dat}
    CUTS_NAME=`basename $CUTSFILE`
    CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
    if [[ "$CUTSFILE" == `basename $CUTSFILE` ]]; then
        CUTSFILE="$VERITAS_EVNDISP_AUX_DIR/GammaHadronCutFiles/$CUTSFILE.dat"
    else
        CUTSFILE="$CUTSFILE.dat"
    fi
    if [[ ! -f "$CUTSFILE" ]]; then
        echo "Error, gamma/hadron cuts file not found, exiting..."
        exit 1
    fi

    OSUBDIR="$ODIR/EffectiveAreas_${CUTS_NAME}"
    if [[ $DISPBDT == "1" ]]; then
        OSUBDIR="${OSUBDIR}_DISP"
    fi
    echo -e "Output files will be written to:\n $OSUBDIR"
    mkdir -p $OSUBDIR
    chmod -R g+w $OSUBDIR

# parameter file template, include "* IGNOREFRACTIONOFEVENTS 0.5" when doing BDT effective areas
    PARAMFILE="
    * FILLINGMODE 0
    * ENERGYRECONSTRUCTIONMETHOD 1
    * ENERGYAXISBINS 60
    * ENERGYAXISBINHISTOS 30
    * EBIASBINHISTOS 75
    * ANGULARRESOLUTIONBINHISTOS 40
    * RESPONSEMATRICESEBINS 200
    * AZIMUTHBINS 1
    * FILLMONTECARLOHISTOS 0
    * ENERGYSPECTRUMINDEX 20 1.6 0.2
    * FILLMONTECARLOHISTOS 0
    ESPECTRUM_FOR_WEIGHTING $VERITAS_EVNDISP_AUX_DIR/AstroData/TeV_data/EnergySpectrum_literatureValues_CrabNebula.dat 5
    * CUTFILE $CUTSFILE
     IGNOREFRACTIONOFEVENTS 0.5        
    * SIMULATIONFILE_DATA $MCFILE"

    # create makeEffectiveArea parameter file
    EAPARAMS="$EFFAREAFILE-${CUTS_NAME}"
    rm -f "$DDIR/$EAPARAMS.dat"
    eval "echo \"$PARAMFILE\"" > $DDIR/$EAPARAMS.dat

# calculate effective areas
    rm -f $OSUBDIR/$OFILE.root 
    $EVNDISPSYS/bin/makeEffectiveArea $DDIR/$EAPARAMS.dat $DDIR/$EAPARAMS.root &> $OSUBDIR/$EAPARAMS.log

    chmod g+w $DDIR/$EAPARAMS.root
    if [[ -f $EVNDISPSYS/bin/logFile ]]; then
        echo "Filling log file into root file"
        $EVNDISPSYS/bin/logFile effAreaLog $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.log
        rm -f $OSUBDIR/$EAPARAMS.log
    else
        chmod g+w $OSUBDIR/$EAPARAMS.log
    fi
    cp -f $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.root

done

exit
