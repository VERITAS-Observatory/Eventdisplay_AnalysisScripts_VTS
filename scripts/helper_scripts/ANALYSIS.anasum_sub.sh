#!/bin/bash
# script to analyse one run with anasum

# set observatory environmental variables
source $EVNDISPSYS/setObservatory.sh VTS

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

EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`

prepare_atmo_string()
{
    ATMO=$1
    EPOCH=$2
    OBSL=$3
    # V4 and V5: grisu sims with ATM21/22
    if [[ $EPOCH == *"V4"* ]] || [[ $EPOCH == *"V5"* ]]; then
        ATMO=${ATMO/6/2}
    fi
    # V6 UV only for ATM 21
    if [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsFilter" ]]; then
       ATMO=${ATMO/62/21}
       ATMO=${ATMO/61/21}
    fi
    echo "$ATMO"
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
    echo "Preparing run list"
    FLIST="$ODIR/$ONAME.runlist"
    rm -f $FLIST
    echo "* VERSION 6" > $FLIST
    echo "" >> $FLIST
    # preparing effective area and radial acceptance names
    RUNINFO=`"$EVNDISPSYS"/bin/printRunParameter "$INDIR/$RUNNUM.mscw.root" -runinfo`
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
    # hardwired setting for redHV: no BDT cuts available,
    # use box cuts for soft and supersoft cuts
    if [[ $OBSL == "obsLowHV" ]]; then
        if [[ $EFFAREARUN == *"SuperSoft"* ]]; then
            echo "RedHV runs - change super soft BDT to super soft box cuts"
            EFFAREARUN=${EFFAREARUN/SuperSoft-NN-TMVA-BDT/SuperSoft}
            RADACCRUN=${RADACCRUN/SuperSoft-NN-TMVA-BDT/SuperSoft}
            CUTFILE=${CUTFILE/SuperSoft-NN-TMVA-BDT/SuperSoft}
        elif [[ $EFFAREARUN == *"Soft"* ]]; then
            echo "RedHV runs - change soft BDT to soft box cuts"
            EFFAREARUN=${EFFAREARUN/Soft-TMVA-BDT/Soft}
            RADACCRUN=${RADACCRUN/Soft-TMVA-BDT/Soft}
            CUTFILE=${CUTFILE/Soft-TMVA-BDT/Soft}
        fi
    fi
    
    echo "EFFAREA $EFFAREARUN"
    echo "RADACCEPTANCE $RADACCRUN"
    echo "CUTFILE $CUTFILE"

    # writing run list
    echo $FLIST
    echo "* $RUNNUM $RUNNUM 0 $CUTFILE $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> $FLIST
fi

# introduce a random sleep to prevent many jobs starting at exactly the same time
NS=$(( ( RANDOM % 10 )  + 1 ))
sleep $NS

#################################
# run anasum
OUTPUTDATAFILE="$ODIR/$ONAME.root"
OUTPUTLOGFILE="$ODIR/$ONAME.log"
$EVNDISPSYS/bin/anasum   \
    -f $RUNP             \
    -l $FLIST            \
    -d $INDIR            \
    -o $OUTPUTDATAFILE   &> $OUTPUTLOGFILE

if [[ -e "$OUTPUTLOGFILE" ]]; then
    $EVNDISPSYS/bin/logFile anasumLog "$OUTPUTDATAFILE" "$OUTPUTLOGFILE"
fi
if [[ -e "$OUTPUTDATAFILE" ]]; then
    $EVNDISPSYS/bin/logFile anasumData "$OUTPUTDATAFILE" "$OUTPUTDATAFILE"
fi

echo "RUN$RUNNUM ANPARLOG log file: $OUTPUTLOGFILE"
echo "RUN$RUNNUM ANPARDATA data file: $OUTPUTDATAFILE"

exit
