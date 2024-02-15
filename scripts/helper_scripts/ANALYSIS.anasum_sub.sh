#!/bin/bash
# script to analyse one run with anasum

# set observatory environmental variables
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    source $EVNDISPSYS/setObservatory.sh VTS
fi
set -e

# parameters replaced by parent script using sed
FLIST=FILELIST
INDIR=DATADIR
ODIR=OUTDIR
ONAME=OUTNAME
RUNP=RUNPARAM
RUNNUM=RUNNNNN
# values used for simple run list
CUTFILE=CCUTFILE
BM=BBM
EFFAREA=EEEFFAREARUN
BMPARAMS="MBMPARAMS"
RADACC=RRADACCRUN
SIMTYPE=SPSIMTYPE
BACKGND=BBACKGND

# default simulation types
SIMTYPE_DEFAULT_V4="GRISU"
SIMTYPE_DEFAULT_V5="GRISU"
SIMTYPE_DEFAULT_V6="CARE_June2020"
SIMTYPE_DEFAULT_V6redHV="CARE_RedHV"
SIMTYPE_DEFAULT_V6UV="CARE_UV_2212"

INFILEPATH="$INDIR/$RUNNUM.mscw.root"
OUTPUTDATAFILE="$ODIR/$ONAME.root"
OUTPUTLOGFILE="$ODIR/$ONAME.log"

# temporary (scratch) directory
if [[ -n $TMPDIR ]]; then
    TEMPDIR=${TMPDIR}/MSCWDISP-$(uuidgen)
else
    TEMPDIR="$VERITAS_USER_DATA_DIR/TMPDIR/MSCWDISP-$(uuidgen)"
fi
mkdir -p $TEMPDIR

# explicit binding for apptainers
if [ -n "$EVNDISP_APPTAINER" ]; then
    APPTAINER_MOUNT=" --bind ${VERITAS_EVNDISP_AUX_DIR}:/opt/VERITAS_EVNDISP_AUX_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${VERITAS_DATA_DIR}:/opt/VERITAS_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind  ${VERITAS_USER_DATA_DIR}:/opt/VERITAS_USER_DATA_DIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${ODIR}:/opt/ODIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${INDIR}:/opt/INDIR "
    APPTAINER_MOUNT=" ${APPTAINER_MOUNT} --bind ${TEMPDIR}:/opt/TEMPDIR"
    echo "APPTAINER MOUNT: ${APPTAINER_MOUNT}"
    APPTAINER_ENV="--env VERITAS_DATA_DIR=/opt/VERITAS_DATA_DIR,VERITAS_EVNDISP_AUX_DIR=/opt/VERITAS_EVNDISP_AUX_DIR,VERITAS_USER_DATA_DIR=/opt/VERITAS_USER_DATA_DIR,VERITASODIR=/opt/ODIR,INDIR=/opt/INDIR,TEMPDIR=/opt/TEMPDIR,LOGDIR=/opt/ODIR"
    EVNDISPSYS="${EVNDISPSYS/--cleanenv/--cleanenv $APPTAINER_ENV $APPTAINER_MOUNT}"
    echo "APPTAINER SYS: $EVNDISPSYS"
    INFILEPATH="/opt/INDIR/$RUNNUM.mscw.root"
    echo "APPTAINER INFILEPATH: $INFILEPATH"
    INDIR="/opt/INDIR/"
    echo "APPTAINER INDIR: $INDIR"
    OUTPUTDATAFILE="/opt/ODIR/$ONAME.root"
    echo "APPTAINER ODIR: $OUTPUTDATAFILE $OUTPUTLOGFILE"
fi

rm -f $OUTPUTLOGFILE
touch $OUTPUTLOGFILE


prepare_atmo_string()
{
    ATMO=$1
    EPOCH=$2
    OBSL=$3
    # V4 and V5: grisu sims with ATM21/22
    if [[ $EPOCH == *"V4"* ]] || [[ $EPOCH == *"V5"* ]]; then
        ATMO=${ATMO/6/2}
    fi
    # V6 UV only for ATM 61
    if [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsFilter" ]]; then
       ATMO=${ATMO/62/61}
    fi
    echo "$ATMO"
}

inspect_executables()
{
    if [ -n "$EVNDISP_APPTAINER" ]; then
        apptainer inspect "$EVNDISP_APPTAINER"
    else
        ls -l ${EVNDISPSYS}/bin/anasum
    fi
}

prepare_irf_string()
{
    EPOCH=$1
    OBSL=$2
    REPLACESIMTYPE=$3
    RADTYPE=$4

    if [[ $REPLACESIMTYPE == "DEFAULT" ]]; then
        if [[ $EPOCH == *"V4"* ]]; then
            REPLACESIMTYPE=${SIMTYPE_DEFAULT_V4}
        elif [[ $EPOCH == *"V5"* ]]; then
            REPLACESIMTYPE=${SIMTYPE_DEFAULT_V5}
        elif [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsLowHV" ]]; then
            if [[ $RADTYPE == "0" ]]; then
                REPLACESIMTYPE=${SIMTYPE_DEFAULT_V6redHV}
            else
                REPLACESIMTYPE=${SIMTYPE_DEFAULT_V6}
            fi
        elif [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsFilter" ]]; then
            if [[ $RADTYPE == "0" ]]; then
                REPLACESIMTYPE=${SIMTYPE_DEFAULT_V6UV}
            else
                REPLACESIMTYPE=${SIMTYPE_DEFAULT_V6}
            fi
        else
            REPLACESIMTYPE=${SIMTYPE_DEFAULT_V6}
        fi
     fi
     echo "$REPLACESIMTYPE"
}

if [[ $FLIST == "NOTDEFINED" ]]; then
    FLIST="$ODIR/$ONAME.runlist"
    echo "Preparing run list $FLIST using $INFILEPATH"
    rm -f $FLIST
    echo "* VERSION 6" > $FLIST
    echo "" >> $FLIST
    # preparing effective area and radial acceptance names
    RUNINFO=$($EVNDISPSYS/bin/printRunParameter "$INFILEPATH" -runinfo)
    EPOCH=`echo "$RUNINFO" | awk '{print $(1)}'`
    MAJOREPOCH=`echo $RUNINFO | awk '{print $(2)}'`
    ATMO=${FORCEDATMO:-`echo $RUNINFO | awk '{print $(3)}'`}
    OBSL=$(echo $RUNINFO | awk '{print $4}')
    TELTOANA=`echo $RUNINFO | awk '{print "T"$(5)}'`

    ATMO=$(prepare_atmo_string $ATMO $EPOCH $OBSL)

    REPLACESIMTYPEEff=$(prepare_irf_string $EPOCH $OBSL $SIMTYPE 0)
    REPLACESIMTYPERad=$(prepare_irf_string $EPOCH $OBSL $SIMTYPE 1)

    echo "RUN $RUNNUM at epoch $EPOCH and atmosphere $ATMO (Telescopes $TELTOANA SIMTYPE $REPLACESIMTYPEEff $REPLACESIMTYPERad)"
    # do string replacements
    if [[ "$BACKGND" == *IGNOREIRF* ]]; then
        EFFAREARUN="IGNOREEFFECTIVEAREA"
    else
        EFFAREARUN=${EFFAREA/VX/$EPOCH}
        EFFAREARUN=${EFFAREARUN/TX/$TELTOANA}
        EFFAREARUN=${EFFAREARUN/XX/$ATMO}
        EFFAREARUN=${EFFAREARUN/SX/$REPLACESIMTYPEEff}
    fi

    if [[ "$BACKGND" == *IGNOREACCEPTANCE* ]] || [[ "$BACKGND" == *IGNOREIRF* ]]; then
        echo "Ignore acceptances: "
        RADACCRUN="IGNOREACCEPTANCE"
    else
        echo "external radial acceptances: "
        RADACCRUN=${RADACC/VX/$MAJOREPOCH}
        RADACCRUN=${RADACCRUN/TX/$TELTOANA}
        RADACCRUN=${RADACCRUN/SX/$REPLACESIMTYPERad}
    fi
    # hardwired setting for redHV and UV: no BDT cuts available,
    # use box cuts for soft and supersoft cuts
    if [[ $OBSL == "obsLowHV" ]] || [[ $OBSL == "obsFilter" ]]; then
        if [[ $EFFAREARUN == *"SuperSoft"* ]]; then
            echo "RedHV runs - change super soft BDT to super soft box cuts"
            EFFAREARUN=${EFFAREARUN/SuperSoft-NN-TMVA-BDT/SuperSoft}
            RADACCRUN=${RADACCRUN/SuperSoft-NN-TMVA-BDT/SuperSoft}
            CUTFILE=${CUTFILE/SuperSoft-NN-TMVA-BDT/SuperSoft}
        else
            echo "RedHV runs - change soft/moderate/hard BDT to soft box cuts"
            EFFAREARUN=${EFFAREARUN/Soft-TMVA-BDT/Soft}
            RADACCRUN=${RADACCRUN/Soft-TMVA-BDT/Soft}
            CUTFILE=${CUTFILE/Soft-TMVA-BDT/Soft}
            EFFAREARUN=${EFFAREARUN/Moderate-TMVA-BDT/Soft}
            RADACCRUN=${RADACCRUN/Moderate-TMVA-BDT/Soft}
            CUTFILE=${CUTFILE/Moderate-TMVA-BDT/Soft}
            EFFAREARUN=${EFFAREARUN/Hard-TMVA-BDT/Soft}
            RADACCRUN=${RADACCRUN/Hard-TMVA-BDT/Soft}
            CUTFILE=${CUTFILE/Hard-TMVA-BDT/Soft}
            EFFAREARUN=${EFFAREARUN/NTel3/NTel2}
            RADACCRUN=${RADACCRUN/NTel3/NTel2}
            CUTFILE=${CUTFILE/NTel3/NTel2}
        fi
    fi

    echo "EFFAREA $EFFAREARUN"
    echo "RADACCEPTANCE $RADACCRUN"
    echo "CUTFILE $CUTFILE"

    # writing run list
    echo $FLIST
    echo "* $RUNNUM $RUNNUM 0 $CUTFILE $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> $FLIST
fi

# copy file list, runparameter and time masks file to tmp disk
cp -v "$FLIST" "$TEMPDIR"
FLIST="${TEMPDIR}/$(basename $FLIST)"
cp -v "$RUNP" "$TEMPDIR"
cp -v $(dirname $RUNP)/$(grep TIMEMASKFILE $RUNP | awk '{print $3}') "$TEMPDIR"
RUNP="${TEMPDIR}/$(basename $RUNP)"

#################################
# run anasum
$EVNDISPSYS/bin/anasum   \
    -f $RUNP             \
    -l $FLIST            \
    -d $INDIR            \
    -o $OUTPUTDATAFILE   &> $OUTPUTLOGFILE

echo "$(inspect_executables)" >> ${OUTPUTLOGFILE}

if [[ -e "$OUTPUTLOGFILE" ]]; then
    $EVNDISPSYS/bin/logFile anasumLog "$OUTPUTDATAFILE" "$(dirname $OUTPUTDATAFILE)/$(basename $OUTPUTLOGFILE)"
fi

echo "RUN$RUNNUM ANPARLOG log file: $OUTPUTLOGFILE"
echo "RUN$RUNNUM ANPARDATA data file: $OUTPUTDATAFILE"

exit
