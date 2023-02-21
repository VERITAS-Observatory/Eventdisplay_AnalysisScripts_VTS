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
RACC=RAAACCC
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
    # V6 redHV only for summer atmospheres
    if [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsLowHV" ]]; then
       ATMO=${ATMO/62/61}
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
        EFFAREA="IGNOREEFFECTIVEAREA"
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
        if [[ ${RACC} == "1" ]]; then
            echo "run-wise radical acceptances: "
            RADACCRUN="$ODIR/$RUNNUM.anasum.radialAcceptance.root"
            echo "   $RADACCRUN"
        elif [[ ${RACC} == "0" ]]; then
            echo "external radial acceptances: "
            RADACCRUN=${RADACC/VX/$MAJOREPOCH}
            RADACCRUN=${RADACCRUN/TX/$TELTOANA}
            RADACCRUN=${RADACCRUN/SX/$REPLACESIMTYPERad}
        fi
    fi
    
    echo "EFFAREA $EFFAREARUN"
    echo "RADACCEPTANCE $RADACCRUN"

    # writing run list
    echo $FLIST
    if [[ $EDVERSION = "v4"* ]]; then
        echo "* $RUNNUM $RUNNUM 0 $CUTFILE $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> $FLIST
    else
        echo "* $RUNNUM $RUNNUM 0 $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> $FLIST
    fi
fi

#################################
# run-wise radial acceptances 
# (if requested)
if [[ ${RACC} == "1" ]]; then
   OUTPUTRACC="$ODIR/$ONAME.radialAcceptance"

   # get run information
   RUNINFO=`"$EVNDISPSYS"/bin/printRunParameter "$INDIR/$RUNNUM.mscw.root" -runinfo`
   # get instrument epoch
   EPOCH=`echo "$RUNINFO" | awk '{print $(2)}'`
   # get teltoana
   TELTOANA=`echo "$RUNINFO" | awk '{print $(5)}'`

   echo "$RUNINFO"
   echo "$EPOCH"
   echo "$TELTOANA"

   # get gamma/hadron cut from run list
   # (depend on cut file version)
   VERS=`cat "$FLIST" | grep '\*' | grep VERSION | awk '{print $3}'`
   if [[ ${VERS} == "7" ]]; then
       # cut file is an effective area file
       RCUT=`cat "$FLIST" | grep '\*' | grep "$RUNNUM" | awk '{print $6}'`
   else
       RCUT=`cat "$FLIST" | grep '\*' | grep "$RUNNUM" | awk '{print $5}'`
   fi
   if [[ $EDVERSION != "v4"* ]]; then
       EXCLUSIONREGION="-f $RUNP"
   fi

   # calculate radial acceptance
   "$EVNDISPSYS"/bin/makeRadialAcceptance -l "$FLIST"  \
                                        -d "$INDIR"  \
                                        -i "$EPOCH"  \
                                        -t "$TELTOANA" \
                                        -c "$RCUT" $EXCLUSIONREGION \
                                        -o "${OUTPUTRACC}.root" &> "${OUTPUTRACC}.log"

   # check statistics
   NEVENTS=$(cat "${OUTPUTRACC}.log" | grep "entries after cuts" | awk -F ": " '{print $2}')
   # check status
   STATUS=$(cat "${OUTPUTRACC}.log" | grep "STATUS=" | tail -n 1 | awk -F "=" '{print $3}' | awk -F " " '{print $1}')
   STATUS=$(grep "RADACC" "${OUTPUTRACC}.log" | wc -l)
   if [ "$NEVENTS" -lt 500 ]; then
     echo "Number of EVENTS ($NEVENTS) below the threshold (500), using averaged radial acceptances" >> ${OUTPUTRACC}.log
     mv ${OUTPUTRACC}.root ${OUTPUTRACC}.lowstatistics.root
   fi
   # check that run-wise raidal acceptance step was successfull
   if [ "$STATUS" < 1 ]; then
     echo 'Fit status is not SUCCESSFUL, using averaged radial acceptances' >> ${OUTPUTRACC}.log
     mv ${OUTPUTRACC}.root ${OUTPUTRACC}.notsuccessful.root
   fi
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
