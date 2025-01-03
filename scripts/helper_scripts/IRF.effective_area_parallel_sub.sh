#!/bin/bash
# calculate effective areas

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
MCFILE=DATAFILE
ODIR=OUTPUTDIR
CUTSFILE="GAMMACUTS"
EFFAREAFILE=EFFFILE
DISPBDT=USEDISP
REDO3TEL="15"

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/EFFAREA/"
else
    DDIR="/tmp/EFFAREA"
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

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

# cp MC file to TMPDIR
cp -f "$MCFILE" "$DDIR"/
MCFILE=`basename $MCFILE`
MCFILE=${DDIR}/${MCFILE}

# Check that cuts file exists
CUTSFILE=${CUTSFILE%%.dat}
CUTS_NAME=`basename $CUTSFILE`
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
if [[ "$CUTSFILE" == `basename $CUTSFILE` ]]; then
    CUTSFILE="$VERITAS_EVNDISP_AUX_DIR"/GammaHadronCutFiles/$CUTSFILE.dat
else
    CUTSFILE="$CUTSFILE.dat"
fi
cp -f "$CUTSFILE" "$DDIR"/
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

# parameter file template, include "* IGNOREFRACTIONOFEVENTS 0.5" when doing BDT effective areas
PARAMFILE="
* FILLINGMODE 0
* ENERGYRECONSTRUCTIONMETHOD 0
* ENERGYAXISBINS 60
* ENERGYAXISBINHISTOS 30
* EBIASBINHISTOS 75
* ANGULARRESOLUTIONBINHISTOS 40
* RESPONSEMATRICESEBINS 200
* AZIMUTHBINS 1
* FILLMONTECARLOHISTOS 0
* ENERGYSPECTRUMINDEX 20 1.6 0.2
* RERUN_STEREO_RECONSTRUCTION_3TEL $REDO3TEL
* CUTFILE $DDIR/$(basename $CUTSFILE)
 IGNOREFRACTIONOFEVENTS 0.5
* SIMULATIONFILE_DATA $MCFILE"

# create makeEffectiveArea parameter file
EAPARAMS="$EFFAREAFILE-${CUTS_NAME}"
rm -f "$DDIR/$EAPARAMS.dat"
eval "echo \"$PARAMFILE\"" > $DDIR/$EAPARAMS.dat

# calculate effective areas
rm -f $OSUBDIR/$OFILE.root
$EVNDISPSYS/bin/makeEffectiveArea $DDIR/$EAPARAMS.dat $DDIR/$EAPARAMS.root &> $OSUBDIR/$EAPARAMS.log

echo "Filling log file into root file"
echo "$(inspect_executables)" >> "$OSUBDIR/$EAPARAMS.log"
cp -v "$OSUBDIR/$EAPARAMS.log" "$DDIR/$EAPARAMS.log"
$EVNDISPSYS/bin/logFile effAreaLog $DDIR/$EAPARAMS.root $DDIR/$EAPARAMS.log
rm -f $OSUBDIR/$EAPARAMS.log
cp -f $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.root
chmod -R g+w $OSUBDIR
chmod g+w $OSUBDIR/$EAPARAMS.root
