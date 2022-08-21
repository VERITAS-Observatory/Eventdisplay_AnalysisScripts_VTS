#!/bin/bash
# script to analyse MC files with lookup tables
# and generate effective areas
# (expect array in wobble offsets and NSB)

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

# parameters replaced by parent script using sed
IINDIR=INPUTDIR
ODIR=OUTPUTDIR
TABFILE=TABLEFILE
ZA=ZENITHANGLE
NNOISE=( NOISELEVEL )
NWOBBLE=( WOBBLEOFFSET )
EEFFAREAFILE=EFFFILE
RECID="RECONSTRUCTIONID"
CUTSLIST="GAMMACUTS"
EPOCH="ARRAYEPOCH"
ATM="ATMOS"
DISPBDT=USEDISP

# output directory
CUTSFILE=${CUTSLIST[0]%%.dat}
CUTS_NAME=`basename $CUTSFILE`
CUTS_NAME=${CUTS_NAME##ANASUM.GammaHadron-}
OSUBDIR="${ODIR}/EffectiveAreas_${CUTS_NAME}"
if [ $DISPBDT -eq 1 ]; then
    OSUBDIR="${OSUBDIR}_DISP"
fi
mkdir -p "$OSUBDIR"
chmod g+w "$OSUBDIR"
echo "Output directory for data products: " $OSUBDIR

# mscw_energy command line options
MOPT="-noNoTrigger -nomctree -writeReconstructedEventsOnly=1 -arrayrecid=${RECID} -tablefile $TABFILE"
echo "MSCW options: $MOPT"

# dispBDT reconstruction
if [ $DISPBDT -eq 1 ]; then
    MOPT="$MOPT -redo_stereo_reconstruction"
    MOPT="$MOPT -tmva_disperror_weight 50"
    MOPT="$MOPT -minangle_stereo_reconstruction=20."
    MOPT="$MOPT -maxloss=0.2"
    # MOPT="$MOPT -maxnevents=1000"
    if [[ ${EPOCH} == *"redHV"* ]]; then
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${EPOCH}_ATM${ATM}_redHV/"
    else
        DISPDIR="${VERITAS_EVNDISP_AUX_DIR}/DispBDTs/${EPOCH}_ATM${ATM}/"
    fi
    if [[ "${ZA}" -lt "40" ]]; then
        DISPDIR="${DISPDIR}/SZE/"
    elif [[ "${ZA}" -lt "50" ]]; then
        DISPDIR="${DISPDIR}/MZE/"
    else
        DISPDIR="${DISPDIR}/LZE/"
    fi
    MOPT="$MOPT -tmva_filename_stereo_reconstruction $DISPDIR/BDTDisp_BDT_"
    MOPT="$MOPT -tmva_filename_disperror_reconstruction $DISPDIR/BDTDispError_BDT_"
    echo "DISP BDT options: $MOPT"
fi

for NOISE in ${NNOISE[@]}; do
  for WOBBLE in ${NWOBBLE[@]}; do

    INDIR=${IINDIR}/ze${ZA}deg_offset${WOBBLE}deg_NSB${NOISE}MHz    

    # file names
    OFILE="${ZA}deg_${WOBBLE}wob_NOISE${NOISE}"

    # echo "CHECKING FOR ${OSUBDIR}/${EEFFAREAFILE}-${WOBBLE}wob-${NOISE}-Cut-NTel2-PointSource-Moderate.root"
    # if [[ -e ${OSUBDIR}/${EEFFAREAFILE}-${WOBBLE}wob-${NOISE}-Cut-NTel2-PointSource-Moderate.root ]]; then
    #    filesize=$(du -h ${OSUBDIR}/${EEFFAREAFILE}-${WOBBLE}wob-${NOISE}-Cut-NTel2-PointSource-Moderate.root | cut -f 1)
    #    echo "FOUND with size $filesize"
    #    if [[ $filesize -ge 800 ]]; then
    #        continue
    #    fi
    # else
    #     echo "NOT FOUND"
    # fi

    # temporary directory
    if [[ -n "$TMPDIR" ]]; then 
        DDIR="$TMPDIR/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
    else
        DDIR="/tmp/MSCW_${ZA}deg_${WOBBLE}deg_NOISE${NOISE}_ID${RECID}"
    fi
    mkdir -p "$DDIR"
    echo "Temporary directory: $DDIR"

    #####################
    # run mscw_energy
    rm -f $OSUBDIR/$OFILE.log
    rm -f $OSUBDIR/$OFILE.list
    if [ -n "$(find ${INDIR} -name "*[0-9].root" 2>/dev/null)" ]; then
        echo "Using evndisp root files from ${INDIR}"
        ls -1 ${INDIR}/*[0-9].root > $OSUBDIR/$OFILE.list
    elif [ -n "$(find  ${INDIR} -name "*[0-9].root.zst" 2>/dev/null)" ]; then
        if command -v zstd /dev/null; then
            echo "Copying evndisp root.zst files to ${DDIR}/evndisp"
            mkdir -p ${DDIR}/evndisp
            FLIST=$(find ${INDIR} -name "*[0-9].root.zst")
            for F in $FLIST
            do
                echo "unpacking $F"
                ofile=$(basename $F .zst)
                zstd -d $F -o ${DDIR}/evndisp/${ofile}
            done
        else
            echo "Error: no zstd installation"
            exit
        fi
        ls -1 ${DDIR}/evndisp/*[0-9].root > $OSUBDIR/$OFILE.list
    fi
    outputfilename="$DDIR/$OFILE.mscw.root"
    logfile="$OSUBDIR/$OFILE.log"
    echo "Starting analysis (log file: $logfile)"
    $EVNDISPSYS/bin/mscw_energy $MOPT \
        -inputfilelist $OSUBDIR/$OFILE.list \
        -outputfile $outputfilename \
        -noise=$NOISE &> $logfile
    rm -rf ${DDIR}/evndisp

    #####################
    # run effective areas
    EFFAREAFILE=${EEFFAREAFILE}-${WOBBLE}wob-${NOISE}

    for CUTSFILE in $CUTSLIST; do
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
        if [ $DISPBDT -eq 1 ]; then
            OSUBDIR="${OSUBDIR}_DISP"
        fi
        echo -e "Output files will be written to:\n $OSUBDIR"
        mkdir -p $OSUBDIR
        chmod -R g+w $OSUBDIR

        echo "EFFFILE $EFFAREAFILE"
        echo "CUTSFILE: $CUTSFILE"

# parameter file template, include "* IGNOREFRACTIONOFEVENTS 0.5" when doing BDT effective areas
        PARAMFILE="
        * OBSERVATORY 1
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
        * SIMULATIONFILE_DATA $outputfilename"

        # create makeEffectiveArea parameter file
        EAPARAMS="$EFFAREAFILE-${CUTS_NAME}"
        rm -f "$DDIR/$EAPARAMS.dat"
        eval "echo \"$PARAMFILE\"" > $DDIR/$EAPARAMS.dat

        # calculate effective areas
        rm -f $OSUBDIR/$OFILE.root 
        $EVNDISPSYS/bin/makeEffectiveArea $DDIR/$EAPARAMS.dat $DDIR/$EAPARAMS.root &> $OSUBDIR/$EAPARAMS.log
        if [[ -f $EVNDISPSYS/bin/logFile ]]; then
            $EVNDISPSYS/bin/logFile effAreaLog $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.log
            rm -f $OSUBDIR/$EAPARAMS.log
            $EVNDISPSYS/bin/logFile mscwTableLog $DDIR/$EAPARAMS.root $logfile
            $EVNDISPSYS/bin/logFile mscwTableList $DDIR/$EAPARAMS.root $OSUBDIR/$OFILE.list
        else
            chmod g+w $OSUBDIR/$EAPARAMS.log
        fi

        cp -f $DDIR/$EAPARAMS.root $OSUBDIR/$EAPARAMS.root
        chmod g+w $OSUBDIR/$EAPARAMS.root
    done
    rm -f "$outputfilename"
    if [[ -f $EVNDISPSYS/bin/logFile ]]; then
        rm -f "$logfile"
        rm -f "$OSUBDIR/$OFILE.list"
    fi
  done
done

exit
