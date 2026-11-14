#!/bin/bash
# shellcheck disable=SC2086
# EVNDISPSYS may include an apptainer exec prefix and must split into command words.
# calculate effective areas
#
# v490: possible issue with "RERUN_STEREO_RECONSTRUCTION_3TEL" option

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
# shellcheck source=/dev/null
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

# parameters replaced by parent script using sed
MCFILE=DATAFILE
DISPBDT=USEDISP
ODIR=OUTPUTDIR
CUTSFILE="GAMMACUTS"
EFFAREAFILE=EFFFILE
REDO3TEL="15"
IRFVERSION="VERSIONIRF"
VARIANT="VVARIANT"
XGBSTEREOFILESUFFIX="STEREOXGB"
XGBGAMMAHADRONFILESUFFIX="GHXGB"

# output directory
[[ ! -d "$ODIR" ]] && mkdir -p "$ODIR" && chmod g+w "$ODIR"
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
    APPTAINER_MOUNT+=" --bind ${DDIR}:${DDIR}"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,DDIR=${DDIR},CALDIR=/opt/ODIR,LOGDIR=/opt/ODIR,ODIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    # path used by EVNDISPSYS needs to be set
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l "${EVNDISPSYS}"/bin/evndisp
    fi
}

# cp XGB files to TMPDIR (if available)
for XGB in "$XGBSTEREOFILESUFFIX" "$XGBGAMMAHADRONFILESUFFIX"
do
    echo "XGB $XGB"
    if [[ -n $XGB ]] && [[ $XGB != "None" ]]; then
        XGBFIL=$(basename $MCFILE .root)
        XGBFIL="$(dirname $MCFILE)/${XGBFIL}.${XGB}.root"
        cp -f -v "$XGBFIL" "$DDIR"/ || { echo "Error: cannot copy $XGBFIL"; exit 1; }
    fi
done
# cp MC file to TMPDIR
cp -f -v "$MCFILE" "$DDIR"/
MCFILE=$(basename $MCFILE)
MCFILE=${DDIR}/${MCFILE}

# Check that cuts file exists
CUTSFILE=${CUTSFILE%%.dat}
CUTS_NAME=$(basename "$CUTSFILE")
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
if [[ "$CUTSFILE" == $(basename "$CUTSFILE") ]]; then
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
[[ -n $VARIANT ]] && OSUBDIR="${OSUBDIR}_${VARIANT}"
echo -e "Output files will be written to:\n $OSUBDIR"
mkdir -p "$OSUBDIR"

ENERGYRECONSTRUCTIONMETHOD="0"
if [[ $IRFVERSION == *"v490"* ]]; then
    ENERGYRECONSTRUCTIONMETHOD="1"
fi

# XGB Reconstruction settings
DIRECTIONRECONSTRUCTIONMETHOD="0"
if [[ $CUTSFILE == *"XGB"* ]]; then
   DIRECTIONRECONSTRUCTIONMETHOD="2"
   ENERGYRECONSTRUCTIONMETHOD="2"
fi

# parameter file template, include "* IGNOREFRACTIONOFEVENTS 0.5" when doing BDT effective areas
PARAMFILE="
* FILLINGMODE 0
* ENERGYRECONSTRUCTIONMETHOD $ENERGYRECONSTRUCTIONMETHOD
* DIRECTIONRECONSTRUCTIONMETHOD $DIRECTIONRECONSTRUCTIONMETHOD
* ENERGYAXISBINS 60
* ENERGYAXISBINHISTOS 30
* EBIASBINHISTOS 75
* ANGULARRESOLUTIONBINHISTOS 200
* RESPONSEMATRICESEBINS 200
* AZIMUTHBINS 1
* FILLMONTECARLOHISTOS 0
* ENERGYSPECTRUMINDEX 40 1.5 0.1
* RERUN_STEREO_RECONSTRUCTION_3TEL $REDO3TEL
* CUTFILE $DDIR/$(basename "$CUTSFILE")
 IGNOREFRACTIONOFEVENTS 0.5
* SIMULATIONFILE_DATA $MCFILE
* XGBSTEREOFILESUFFIX $XGBSTEREOFILESUFFIX
* XGBGAMMAHADRONFILESUFFIX $XGBGAMMAHADRONFILESUFFIX"

# create makeEffectiveArea parameter file
EAPARAMS="$EFFAREAFILE-${CUTS_NAME}"
rm -f "$DDIR/$EAPARAMS.dat"
eval "echo \"$PARAMFILE\"" > "$DDIR"/"$EAPARAMS".dat

# Guard each variant output, including concurrent submissions.
if [[ -n $VARIANT ]]; then
    [[ ! -e "$OSUBDIR/$EAPARAMS.root" && ! -e "$OSUBDIR/$EAPARAMS.log" ]] || { echo "Error: output already exists: $OSUBDIR/$EAPARAMS"; exit 1; }
    mkdir "$OSUBDIR/$EAPARAMS.lock" || { echo "Error: output locked: $EAPARAMS"; exit 1; }
    trap 'rmdir "$OSUBDIR/$EAPARAMS.lock"' EXIT
    [[ ! -e "$OSUBDIR/$EAPARAMS.root" && ! -e "$OSUBDIR/$EAPARAMS.log" ]] || exit 1
fi
# calculate effective areas
rm -f "$OSUBDIR"/"$OFILE".root
$EVNDISPSYS/bin/makeEffectiveArea "$DDIR"/"$EAPARAMS".dat "$DDIR"/"$EAPARAMS".root &> "$OSUBDIR"/"$EAPARAMS".log
EA_STATUS=$?
if [[ -n $VARIANT && $EA_STATUS -ne 0 ]]; then
    echo "Error: makeEffectiveArea failed ($EA_STATUS)."; exit "$EA_STATUS"
fi

echo "Filling log file into root file"
inspect_executables >> "$OSUBDIR/$EAPARAMS.log"
cp -v "$OSUBDIR/$EAPARAMS.log" "$DDIR/$EAPARAMS.log"
$EVNDISPSYS/bin/logFile effAreaLog "$DDIR"/"$EAPARAMS".root "$DDIR"/"$EAPARAMS".log
if [[ -n $VARIANT ]]; then
    [[ -s "$DDIR/$EAPARAMS.root" ]] || { echo "Error: missing effective area output"; exit 1; }
    TEMP_OUTPUT="$OSUBDIR/$EAPARAMS.tmp.$$.root"
    cp "$DDIR/$EAPARAMS.root" "$TEMP_OUTPUT" || exit 1
    ln "$TEMP_OUTPUT" "$OSUBDIR/$EAPARAMS.root" || { rm -f "$TEMP_OUTPUT"; exit 1; }
    rm -f "$TEMP_OUTPUT"
else
    cp -f "$DDIR/$EAPARAMS.root" "$OSUBDIR/$EAPARAMS.root"
fi
chmod -R g+w "$OSUBDIR"
chmod g+w "$OSUBDIR"/"$EAPARAMS".root
rm -f "$OSUBDIR"/"$EAPARAMS".log
