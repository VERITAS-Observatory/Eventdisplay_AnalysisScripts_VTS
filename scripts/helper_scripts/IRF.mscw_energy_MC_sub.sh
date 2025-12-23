#!/bin/bash
# Analyse MC files with lookup tables (mscw_energy stage)
# (optional) Calculate instrument response functions (effective areas) for 4 and 3-telescope combinations

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi
set -e

# parameters replaced by parent script using sed
TABFILE=TABLEFILE
ZA=ZENITHANGLE
NOISE=NOISELEVEL
WOBBLE=WOBBLEOFFSET
ANATYPE=ANALYSISTYPE
EPOCH="ARRAYEPOCH"
ATM=ATMOSPHERE
RECID="RECONSTRUCTIONID"
IRFVERSION=VERSIONIRF
SIMTYPE=SIMULATIONTYPE
DISPBDT=USEDISP
INDIR=INPUTDIR
ODIR=OUTPUTDIR
# Set EFFAREACUTLIST to 'NOEFFAREA' to run mscw analysis only
EFFAREACUTLIST=EEFFAREACUTLIST
XGBVERSION=VERSIONXGB
env_name="eventdisplay_ml"

# output directory
[[ ! -d "$ODIR" ]] && mkdir -p "$ODIR" && chmod g+w "$ODIR"
OSUBDIR="$ODIR/MSCW_RECID${RECID}"
if [ $DISPBDT -eq 1 ]; then
    OSUBDIR="${OSUBDIR}_DISP"
fi
mkdir -p "$OSUBDIR"
chmod g+w "$OSUBDIR"
echo "Output directory for data products: " $OSUBDIR

# file names
OFILE="${ZA}deg_${WOBBLE}wob_NOISE${NOISE}"

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
else
    DDIR="/tmp/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
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
    TABFILE="/opt/VERITAS_EVNDISP_AUX_DIR/Tables/$(basename $TABFILE)"
fi

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/mscw_energy
    fi
}


# mscw_energy command line options
MOPT="-noNoTrigger -nomctree -writeReconstructedEventsOnly=1 -arrayrecid=${RECID} -tablefile $TABFILE"
# dispBDT reconstruction
if [ $DISPBDT -eq 1 ]; then
    MOPT="$MOPT -redo_stereo_reconstruction"
    MOPT="$MOPT -tmva_disperror_weight 50"
    MOPT="$MOPT -minangle_stereo_reconstruction=10."
    if [[ $IRFVERSION == v490* ]]; then
        MOPT="$MOPT -maxloss=0.20"
    else
        MOPT="$MOPT -maxdist=1.75 -minntubes=5 -minwidth=0.02 -minsize=100"
        MOPT="$MOPT -maxloss=0.40"
        MOPT="$MOPT -use_evndisp_selected_images=0"
    fi
    # MOPT="$MOPT -maxnevents=1000"
    if [[ ${SIMTYPE} == *"RedHV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}_redHV/"
    elif [[ ${SIMTYPE} == *"UV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}_UV/"
    else
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${ANATYPE}/${EPOCH}_ATM${ATM}/"
    fi
    if [[ "${ZA}" -lt "38" ]]; then
        DISPDIR="${DISPDIR}/SZE/"
    elif [[ "${ZA}" -lt "48" ]]; then
        DISPDIR="${DISPDIR}/MZE/"
    elif [[ "${ZA}" -lt "58" ]]; then
        DISPDIR="${DISPDIR}/LZE/"
    else
        DISPDIR="${DISPDIR}/XZE/"
    fi
    # unzip XML files into DDIR
    cp -v -f ${DISPDIR}/*.xml.gz ${DDIR}/
    gunzip -v ${DDIR}/*xml.gz
    MOPT="$MOPT -tmva_filename_stereo_reconstruction ${DDIR}/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction ${DDIR}/BDTDispError_BDT_"
    MOPT="$MOPT -tmva_filename_dispsign_reconstruction ${DDIR}/BDTDispSign_BDT_"
    if [[ $IRFVERSION != v490* ]]; then
        MOPT="$MOPT -tmva_filename_energy_reconstruction ${DDIR}/BDTDispEnergy_BDT_"
    fi
    echo "DISP BDT options: $MOPT"
fi

# input evndisp files
rm -f $OSUBDIR/$OFILE.log
rm -f $OSUBDIR/$OFILE.list
echo "INDIR ${INDIR}"
if [ -n "$(find "${INDIR}/" -name "*[0-9].root" 2>/dev/null)" ]; then
    echo "Using evndisp root files from ${INDIR}"
    cp -v "${INDIR}/*[0-9].root" "$DDIR"
elif [ -n "$(find  "${INDIR}/" -name "*[0-9].root.zst" 2>/dev/null)" ]; then
    if command -v zstd /dev/null; then
        echo "Copying evndisp root.zst files to ${DDIR}"
        FLIST=$(find "${INDIR}/" -name "*[0-9].root.zst")
        for F in $FLIST
        do
            echo "unpacking $F"
            cp -v -f $F ${DDIR}/
            ofile=$(basename $F .zst)
            zstd -d ${DDIR}/${ofile}.zst -o ${DDIR}/${ofile}
        done
    else
        echo "Error: no zstd installation"
        exit
    fi
fi
ls -1 "$DDIR"/*[0-9].root > "$DDIR/$OFILE.list"
echo "Evndisp files:"
cat "$DDIR/$OFILE.list"

echo "Running mscw_energy"
outputfilename="$DDIR/$OFILE.mscw.root"
logfile="$OSUBDIR/$OFILE.log"
$EVNDISPSYS/bin/mscw_energy $MOPT \
    -inputfilelist "$DDIR/$OFILE.list" \
    -outputfile $outputfilename \
    -noise=$NOISE &> $logfile

echo "READING evndisp files from ${INDIR}" >> $logfile
# add DISP directory to log file
# (as XML files are unpacked to tmp directory)
if [ $DISPBDT -eq 1 ]; then
    echo "Reading DISPBDT XML files from ${DISPDIR}" >> $logfile
fi

echo "$(inspect_executables)" >> "$logfile"
cp -v "$logfile" "$DDIR/$OFILE.log"
$EVNDISPSYS/bin/logFile mscwTableLog $outputfilename "$DDIR/$OFILE.log"

# cp results file back to data directory and clean up
outputbasename=$( basename $outputfilename )
chmod g+w "$logfile"
if [[ $EFFAREACUTLIST == "NOEFFAREA" ]]; then
    cp -f -v $outputfilename $OSUBDIR/$outputbasename
    chmod g+w "$OSUBDIR/$outputbasename"
    exit
fi

###########################################################################
# Effective area generation
###########################################################################
echo "Effective area generation (cut list: $EFFAREACUTLIST)"

# read cut list file
read_cutlist()
{
    CUTFILE="${1}"
    if [[ $CUTFILE == "" ]] || [ ! -f $CUTFILE ]; then
        echo "Error, cuts list file not found, exiting..." >&2
        echo $CUTFILE
        exit 1
    fi
    CUTLISTFROMFILE=$(cat $CUTFILE)
    CUTLIST=""
    for CUT in ${CUTLISTFROMFILE[@]}; do
        CUTLIST="${CUTLIST} ANASUM.GammaHadron-Cut-$CUT.dat"
    done
    echo $CUTLIST
}

# Required for DISP XGB
check_conda_installation()
{
    if command -v conda &> /dev/null; then
        echo "Found conda installation."
    else
        echo "Error: found no conda installation."
        echo "exiting..."
        exit
    fi
    env_info=$(conda info --envs)
    if [[ "$env_info" == *"$env_name"* ]]; then
        echo "Found conda environment '$env_name'"
    else
        echo "Error: the conda environment '$env_name' does not exist."
        echo "exiting..."
        exit
    fi
}

###############################################
# Run XGB DISP reconstruction
###############################################
get_xgb_output_file()
{
    XGBOFIL=$(basename $MSCW_FILE .root)
    XGBOFIL="${DDIR}/${XGBOFIL}.${XGBVERSION}_ImgSel${1}"
    echo "$XGBOFIL"
}


run_xgb()
{
    check_conda_installation
    source activate base
    conda activate $env_name
    MSCW_FILE="$outputfilename"
    ZA=$(basename "$MSCW_FILE" | cut -d'_' -f1)
    ZA=${ZA%deg}
    echo "MSCW file: ${MSCW_FILE} at zenith ${ZA} deg"

    DISPDIR="$VERITAS_EVNDISP_AUX_DIR/DispXGB/${ANATYPE}/${EPOCH}_ATM${ATM}/"
    if [[ "${ZA}" -lt "38" ]]; then
        DISPDIR="${DISPDIR}/SZE/"
    elif [[ "${ZA}" -lt "48" ]]; then
        DISPDIR="${DISPDIR}/MZE/"
    elif [[ "${ZA}" -lt "58" ]]; then
        DISPDIR="${DISPDIR}/LZE/"
    else
        DISPDIR="${DISPDIR}/XZE/"
    fi
    echo "DispXGB directory $DISPDIR"
    echo "DispXGB options $XGBVERSION"
    XGBOFIL=$(get_xgb_output_file $1)
    echo "XGB Output file $XGBOFIL"
    echo "DispXGB inputfle $MSCW_FILE"

    rm -f "$XGBOFIL".log

    eventdisplay-ml-apply-xgb-stereo \
        --input-file "$MSCW_FILE" \
        --model-dir "$DISPDIR" \
        --output-file "$XGBOFIL.root" \
        --image-selection $1 > "$XGBOFIL.log" 2>&1

    python --version >> "${XGBOFIL}.log"
    conda list -n $env_name >> "${XGBOFIL}.log"

    conda deactivate
    echo "Finished calculated XGB"
}

CUTLIST=$(read_cutlist "$EFFAREACUTLIST")

# loop over 4 and 3-telescope combinations
for ID in 15 14 13 11 7; do
    # Gamma/hadron cut list (depends on analysis and observation type)
    for CUTSFILE in ${CUTLIST[@]}; do
        echo "Calculate effective areas $CUTSFILE (ID $ID)"
        EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID${RECID}-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        if [[ $ID == "15" ]]; then
            EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID0-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        elif [[ $ID == "14" ]]; then
            EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID2-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        elif [[ $ID == "13" ]]; then
            EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID3-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        elif [[ $ID == "11" ]]; then
            EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID4-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        elif [[ $ID == "7" ]]; then
            EFFAREAFILE="EffArea-${SIMTYPE}-${EPOCH}-ID5-Ze${ZA}deg-${WOBBLE}wob-${NOISE}"
        fi
        # Check that cuts file exists
        CUTSFILE=${CUTSFILE%%.dat}
        echo $CUTSFILE
        CUTS_NAME=$(basename $CUTSFILE)
        CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
        if [[ "$CUTSFILE" == $(basename $CUTSFILE) ]]; then
            CUTSFILE="$VERITAS_EVNDISP_AUX_DIR"/GammaHadronCutFiles/$CUTSFILE.dat
        else
            CUTSFILE="$CUTSFILE.dat"
        fi
        cp -v -f "$CUTSFILE" "$DDIR"/
        if [[ ! -f "$CUTSFILE" ]]; then
            echo "Error, gamma/hadron cuts file $CUTSFILE not found, exiting..."
            exit 1
        fi

        OSUBDIR="$ODIR/EffectiveAreas_${CUTS_NAME}"
        if [[ $DISPBDT == "1" ]]; then
            OSUBDIR="${OSUBDIR}_DISP"
        fi
        echo -e "Output files will be written to:\n $OSUBDIR"
        mkdir -p $OSUBDIR

        if [[ -n $XGBVERSION ]] && [[ $XGBVERSION != "None" ]]; then
            XGBFILESUFFIX=${XGBVERSION}_ImgSel${ID}
        else
            XGBFILESUFFIX=None
        fi

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
* ENERGYSPECTRUMINDEX 40 1.5 0.1
* RERUN_STEREO_RECONSTRUCTION_3TEL $ID
* CUTFILE $DDIR/$(basename $CUTSFILE)
 IGNOREFRACTIONOFEVENTS 0.5
* SIMULATIONFILE_DATA $outputfilename
* XGBFILESUFFIX ${XGBFILESUFFIX}"

        if [[ -n $XGBVERSION ]] && [[ $XGBVERSION != "None" ]]; then
            run_xgb $ID
        fi

        # create makeEffectiveArea parameter file
        EAPARAMS="$EFFAREAFILE-${CUTS_NAME}"
        rm -f "$DDIR/$EAPARAMS.dat"
        eval "echo \"$PARAMFILE\"" > $DDIR/$EAPARAMS.dat
        echo "Run parameter file:"
        cat $DDIR/$EAPARAMS.dat

        # calculate effective areas
        rm -f $OSUBDIR/$OFILE.root
        $EVNDISPSYS/bin/makeEffectiveArea $DDIR/$EAPARAMS.dat $DDIR/$EAPARAMS.root &> $OSUBDIR/$EAPARAMS.log

        echo "Filling effAreaLog file into root file: $OSUBDIR/$EAPARAMS.log"
        echo "$(inspect_executables)" >> "$OSUBDIR/$EAPARAMS.log"
        cp "$OSUBDIR/$EAPARAMS.log" "$DDIR/$EAPARAMS.log"
        $EVNDISPSYS/bin/logFile effAreaLog $DDIR/$EAPARAMS.root $DDIR/$EAPARAMS.log
        echo "Filling mscwTableLog file into root file: $OSUBDIR/$EAPARAMS.log"
        $EVNDISPSYS/bin/logFile mscwTableLog $DDIR/$EAPARAMS.root "$DDIR/$OFILE.log"
        echo "Trying to fill XGB log file into root file: $OSUBDIR/$EAPARAMS.log"
        if [[ -n $XGBVERSION ]] && [[ $XGBVERSION != "None" ]]; then
            XGBLOGFILE="$(get_xgb_output_file $ID).log"
            if [[ -f "$XGBLOGFILE" ]]; then
                $EVNDISPSYS/bin/logFile xgbLog $DDIR/$EAPARAMS.root "$XGBLOGFILE"
            else
                echo "XGB log file $XGBLOGFILE not found, skipping."
            fi
        fi
        rm -f $OSUBDIR/$EAPARAMS.log
        cp -f -v $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.root
        chmod -R g+w $OSUBDIR
        chmod g+w $OSUBDIR/$EAPARAMS.root
    done
done
