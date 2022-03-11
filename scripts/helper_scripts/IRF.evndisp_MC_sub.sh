#!/bin/bash
# script to run evndisp for simulations on one of the cluster nodes (VBF)

# set observatory environmental variables
source "$EVNDISPSYS"/setObservatory.sh VTS

########################################################
# parameters replaced by parent script using sed
RUNNUM=RUNNUMBER
SIMDIR=DATADIR
ZA=ZENITHANGLE
WOB=DECIMALWOBBLE
WOG=INTEGERWOBBLE
NOISE=NOISELEVEL
EPOCH=ARRAYEPOCH
ATM=ATMOSPHERE
ACUTS="RECONSTRUCTIONRUNPARAMETERFILE"
SIMTYPE=SIMULATIONTYPE
ODIR=OUTPUTDIR
NEVENTS=NENEVENT
TELTOANA="1234"
VBFNAME=VBFFFILE
NOISEFILE=NOISEFFILE
EDVERSION=VVERSION
ADDOPT="ADDITIONALOPTIONS"

# number of pedestal events
PEDNEVENTS="200000"
TZERONEVENTS="100000"

echo "PROCESS ID ${Process}"
echo "SGE_ID ${SGE_TASK_ID}"
if [[ $NEVENTS -gt 0 ]]; then
    if [[ -z $SGE_TASK_ID ]]; then
        ITER=$((SGE_TASK_ID - 1))
    else
        ITER=$((Process - 1))
    fi
    FIRSTEVENT=$(($ITER * $NEVENTS))
    # increase run number
    RUNNUM=$((RUNNUM + $ITER))
    echo -e "ITER $ITER NEVENTS $NEVENTS FIRSTEVENT $FIRSTEVENT"
fi

# Output file name
ONAME="$RUNNUM"
echo "Runnumber $RUNNUM"

#################################
# detector configuration and cuts
echo "Using run parameter file $ACUTS"

DEAD="EVNDISP.validchannels.dat"
# default pedestal level
# (same for GRISU and CARE,
#  adjustments possibly needed)
PEDLEV="16."
# LOWPEDLEV="8."
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
    LOWPEDLEV="${PEDLEV}"
else
    LOWPEDLEV="16."
fi

# Amplitude correction factor options
AMPCORR="-traceamplitudecorrection ThroughputCorrection.runparameter -pedestalDefaultPedestal=$PEDLEV"
# CARE simulations: add Gaussian noise of 3.6 mV/ (7.84 mV/dc)  / 2
# Current (2018) CARE simulations:
#    no electronic noise included - therefore add
#    Gaussian noise with the given width
#    Derived for GrIsu many years ago - source not entirely clear
#    add Gaussian noise of 3.6 mV/ (7.84 mV/dc)  / 2
if [[ ${SIMTYPE:0:4} == "CARE" ]]; then
    AMPCORR="$AMPCORR -injectGaussianNoise=0.229592"
fi

# detector configuration
[[ ${EPOCH:0:2} == "V4" ]] && CFG="EVN_V4_Oct2012_oldArrayConfig_20130428_v420.txt"
[[ ${EPOCH:0:2} == "V5" ]] && CFG="EVN_V5_Oct2012_newArrayConfig_20121027_v420.txt"
[[ ${EPOCH:0:2} == "V6" ]] && CFG="EVN_V6_Upgrade_20121127_v420.txt"

# temporary directory
if [[ -n "$TMPDIR" ]]; then 
    DDIR="$TMPDIR/evn_${ZA}_${NOISE}_${WOG}"
else
    DDIR="/tmp/evn_${ZA}_${NOISE}_${WOG}"
fi
mkdir -p "$DDIR"
echo "Temporary directory: $DDIR"
CALDIR=${DDIR}
mkdir -p ${CALDIR}/Calibration
echo "Calibration directory: ${CALDIR}"

##################3
# unzip vbf file to local scratch directory
if [[ -f "${SIMDIR}/$VBFNAME" ]]; then
   ZTYPE=${VBFNAME##*.}
   if [[ $ZTYPE == "gz" ]]; then
       echo " (vbf is gzipped)"
       VBF_FILE=$(basename $SIMDIR/${VBFNAME} .gz)
       gunzip -f -q -c $SIMDIR/${VBFNAME} > ${DDIR}/${VBF_FILE}
   elif [[ $ZTYPE == "bz2" ]]; then
       echo " (vbf is bzipped)"
       VBF_FILE=$(basename $SIMDIR/${VBFNAME} .bz2)
       bunzip2 -f -q -c $SIMDIR/${VBFNAME} > ${DDIR}/${VBF_FILE}
   elif [[ $ZTYPE == "zst" ]]; then
       echo " (vbf is zst-compressed)"
       if hash zstd 2>/dev/null; then
           VBF_FILE=$(basename $SIMDIR/${VBFNAME} .zst)
           zstd -d -f ${SIMDIR}/${VBFNAME} -o ${DDIR}/${VBF_FILE}
       else
            echo "no zstd installed; exiting"
            exit
       fi
    else
       echo "Unknown file extension $ZTYPE ,exiting"
       exit
    fi
fi
ls -lh $DDIR/

# check that the uncompressed vbf file exists
if [[ ! -f "$DDIR/$VBF_FILE" ]]; then
    echo "No source file found: $DDIR/$VBF_FILE"
    echo "Simulation file: $SIMDIR/$VBFNAME"
    exit 1
fi
VBF_FILE="$DDIR/$VBF_FILE"

#######################################
# option for all steps of the analysis
MCOPT=" -runnumber=$RUNNUM -sourcetype=2 -epoch $EPOCH -camera=$CFG" 
MCOPT="$MCOPT -reconstructionparameter $ACUTS -sourcefile $VBF_FILE"
MCOPT="$MCOPT -deadchannelfile $DEAD -donotusedbinfo -calibrationdirectory ${CALDIR}"
MCOPT="$MCOPT $AMPCORR"
MCOPT="$MCOPT ${ADDOPT}"

# Low gain calibration
LOWGAINCALIBRATIONFILE=NOFILE
if [[ ${SIMTYPE:0:4} = "CARE" ]]; then
   if [[ $EDVERSION = "v4"* ]]; then
       if [[ ! -f ${CALDIR}/Calibration/calibrationlist.LowGainForCare.dat ]]; then
          cp -f $VERITAS_EVNDISP_AUX_DIR/Calibration/calibrationlist.LowGainForCare.dat ${CALDIR}/Calibration/calibrationlist.LowGainForCare.dat
       fi
       LOWGAINCALIBRATIONFILE=calibrationlist.LowGainForCare.dat
   else
       if [[ ! -f ${CALDIR}/Calibration/calibrationlist.LowGainForCare.${EPOCH:0:2}.dat ]]; then
          cp -f $VERITAS_EVNDISP_AUX_DIR/Calibration/calibrationlist.LowGainForCare.${EPOCH:0:2}.dat ${CALDIR}/Calibration/calibrationlist.LowGainForCare.${EPOCH:0:2}.dat
       fi
       LOWGAINCALIBRATIONFILE=calibrationlist.LowGainForCare.${EPOCH:0:2}.dat
   fi
fi

###############################################
# calculate pedestals
# (CARE only, GRISU used external noise file)
if [[ ${SIMTYPE:0:4} == "CARE" ]]; then
    echo "Calculating pedestals for run $RUNNUM"
    rm -f $ODIR/$RUNNUM.ped.log
    PEDOPT="-runmode=1 -calibrationnevents=${PEDNEVENTS}"
    $EVNDISPSYS/bin/evndisp $MCOPT $PEDOPT &> $ODIR/$RUNNUM.ped.log
    if grep -Fq "END OF ANALYSIS, exiting" $ODIR/$RUNNUM.ped.log;
    then
        echo "   successful pedestal analysis"
    else
        echo "   echo in pedestal analysis"
        exit
    fi
fi    

###############################################
# calculate tzeros
echo "Calculating average tzeros for run $RUNNUM"
TZEROPT="-runmode=7 -calibrationnevents=${TZERONEVENTS} -pedestalnoiselevel=$NOISE "
TZEROPT="$TZEROPT -lowgainpedestallevel=$LOWPEDLEV -lowgaincalibrationfile ${LOWGAINCALIBRATIONFILE}"
rm -f $ODIR/$RUNNUM.tzero.log
### eventdisplay GRISU run options
if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
   TZEROPT="$TZEROPT -pedestalfile $NOISEFILE -pedestalseed=$RUNNUM -pedestalDefaultPedestal=$PEDLEV" 
fi
echo "$EVNDISPSYS/bin/evndisp $MCOPT $TZEROPT" &> $ODIR/$RUNNUM.tzero.log
$EVNDISPSYS/bin/evndisp $MCOPT $TZEROPT &>> $ODIR/$RUNNUM.tzero.log
if grep -Fq "END OF ANALYSIS, exiting" $ODIR/$RUNNUM.tzero.log;
then
    echo "   successful tzero analysis"
else
    echo "   echo in tzero analysis"
    exit
fi

###############################################
# run eventdisplay
###############################################

#####################
# general analysis options
ANAOPT=" -writenomctree -outputfile $DDIR/$ONAME.root"
ANAOPT="$ANAOPT -lowgaincalibrationfile ${LOWGAINCALIBRATIONFILE} -lowgainpedestallevel=$PEDLEV"
#
######################
## options for GRISU (handling of low-gain values)
if [[ ${SIMTYPE:0:5} == "GRISU" ]]; then
    ANAOPT="$ANAOPT -simu_hilo_from_simfile -pedestalfile $NOISEFILE -pedestalseed=$RUNNUM -pedestalDefaultPedestal=$PEDLEV"
fi
# first event for analysis
if [[ $NEVENTS -gt 0 ]]; then
	 ANAOPT="-nevents=$NEVENTS -firstevent=$FIRSTEVENT $ANAOPT"
fi
#################################################################################
# run evndisp
echo "Analysing MC file for run $RUNNUM"
echo "$EVNDISPSYS/bin/evndisp $MCOPT $ANAOPT" &> $ODIR/$ONAME.log
$EVNDISPSYS/bin/evndisp $MCOPT $ANAOPT &>> $ODIR/$ONAME.log

#################################################################################
# remove temporary files
ls -lh "$DDIR"
cp -f -v "$DDIR/$ONAME.root" "$ODIR/$ONAME.root"
cp -r -f -v ${CALDIR}/Calibration ${ODIR}/
chmod g+w "$ODIR/$ONAME.root"
chmod g+w "$ODIR/$ONAME.log"
chmod g+w "$ODIR/$ONAME.tzero.log"
chmod -R g+w $ODIR/Calibration
rm -f -v "$DDIR/$ONAME.root"
rm -f -v "$VBF_FILE"

echo "EVNDISP output root file written to $ODIR/$ONAME.root"
echo "EVNDISP log file written to $ODIR/$ONAME.log"

exit
