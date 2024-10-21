#!/bin/bash
# script to run evndisp for simulations on one of the cluster nodes (VBF)

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source "$EVNDISPSYS"/setObservatory.sh VTS
fi

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
TELTOANA="1234"
VBFNAME=VBFFFILE
NOISEFILE=NOISEFFILE
EDVERSION=VVERSION
ADD_OPT="ADDITIONALOPTIONS"

# number of pedestal events
PEDNEVENTS="10000"
TZERONEVENTS="10000"

echo "PROCESS ID ${Process}"
echo "SGE_ID ${SGE_TASK_ID}"

# Output file name
ONAME="$RUNNUM"
echo "Runnumber $RUNNUM"

# check if output file exist
V4N=${ODIR/v490/v4N}
if [ -e "$V4N/$ONAME.root.zst" ]; then
    zstd --test $V4N/$ONAME.root.zst
    echo "OUTPUT $V4N/$ONAME.root.zst exists; skipping this job"
    exit
fi

# temporary directory
if [[ -n "$TMPDIR" ]]; then
    DDIR="$TMPDIR/evn_${ZA}_${NOISE}_${WOG}"
else
    DDIR="/tmp/evn_${ZA}_${NOISE}_${WOG}"
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

#################################
echo "Using run parameter file $ACUTS"

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/evndisp
    fi
}

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
MCOPT="$MCOPT ${ADD_OPT}"

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
    $EVNDISPSYS/bin/evndisp $MCOPT $PEDOPT &> "$ODIR/$RUNNUM.ped.log"
    echo "$(inspect_executables)" >> "$ODIR/$RUNNUM.ped.log"
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
echo "$(inspect_executables)" &>> "$ODIR/$RUNNUM.tzero.log"
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
#################################################################################
# run evndisp
echo "Analysing MC file for run $RUNNUM"
echo "$EVNDISPSYS/bin/evndisp $MCOPT $ANAOPT" &> $ODIR/$ONAME.log
$EVNDISPSYS/bin/evndisp $MCOPT $ANAOPT &>> $ODIR/$ONAME.log
echo "$(inspect_executables)" >> "$ODIR/$ONAME.log"

#################################################################################
# cleanup
ls -lh "$DDIR"
cp -r -f -v ${CALDIR}/Calibration ${ODIR}/
rm -f -v "$VBF_FILE"

echo "EVNDISP output root file written to $ODIR/$ONAME.root"
echo "EVNDISP log file written to $ODIR/$ONAME.log"
#################################################################################
# add log files to eventdisplay files and compress file

### add log files to evndisp file
add_log_file()
{
     # first check if logFile is already included in evndisp file
     LCON=$($EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root | grep "Error: log file object" | wc -l)
     if [[ ${LCON} == 1 ]]; then
         echo "writing log file ${2}"
         if [[ -f ${2} ]]; then
             $EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root ${2}
         fi
     else
         echo "log file ${2} already in $DDIR/$ONAME.root"
     fi
}

cp -v  "$ODIR/$ONAME.log"  "$DDIR/$ONAME.log"
add_log_file evndispLog "$DDIR/$ONAME.log"
cp -v "$ODIR/$ONAME.ped.log" "$DDIR/$ONAME.ped.log"
add_log_file evndisppedLog "$DDIR/$ONAME.ped.log"
cp -v "$ODIR/$ONAME.tzero.log" "$DDIR/$ONAME.tzero.log"
add_log_file evndisptzeroLog "$DDIR/$ONAME.tzero.log"

### check that log files are filled correctly
compare_log_file()
{
    $EVNDISPSYS/bin/logFile $1 $DDIR/$ONAME.root > ${DDIR}/${1}.log
    if cmp -s "${2}" "${DDIR}/${1}.log"; then
        echo "FILES ${1} ${2} are the same, removing"
        rm -f "${2}"
    else
        touch $ODIR/$ONAME.${1}.errorlog
        echo "Error, ${1} ${2} differ" >> $ODIR/$ONAME.${1}.errorlog
    fi
}

compare_log_file evndispLog $ODIR/$ONAME.log
if [ -e $ODIR/$ONAME.ped.log ]; then
    compare_log_file evndisppedLog $ODIR/$ONAME.ped.log
fi
compare_log_file evndisptzeroLog $ODIR/$ONAME.tzero.log

### compress evndisp root file
compress_file()
{
    if command -v zstd /dev/null; then
        zstd ${1}
        zstd --test ${1}.zst
    else
        echo "Error: zstd compressing executable not found"
        exit
    fi
}

compress_file $DDIR/$ONAME.root
mv -f -v $DDIR/$ONAME.root.zst ${ODIR}/

### set group permissions
chmod g+w "$ODIR/$ONAME.root.zst"
chmod -R g+w $ODIR/Calibration
