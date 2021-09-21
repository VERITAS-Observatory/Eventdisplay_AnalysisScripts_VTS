#!/bin/bash
# script to analyse VTS data files with lookup tables

# qsub parameters
h_cpu=00:29:00; h_vmem=2000M; tmpdir_size=4G

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d .`

if [ $# -lt 2 ]; then
# begin help message
echo "
MSCW_ENERGY data analysis: submit jobs from a simple run list

ANALYSIS.mscw_energy.sh <runlist> [evndisp directory] [output directory] [Rec ID] [sim type] [ATM]

required parameters:
			
    <runlist>               simple run list with one run number per line.    
    
    

optional parameters:

    [evndisp directory]     directory containing evndisp output ROOT files.
			    Default: $VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/

    [output directory]      directory where mscw.root files are written
                            default: <evndisp directory>

    [Rec ID]                reconstruction ID. Default 0
                            (see EVNDISP.reconstruction.runparameter)
    
    [simulation type]       e.g. CARE_June2020 (this is the default)

    [ATM]                   set atmosphere ID (overwrite the value from the evndisp stage)

--------------------------------------------------------------------------------
"

#end help message
exit
fi

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d .`
IRFVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d . | sed -e 's/[a-zA-Z]*$//'`

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# create extra stdout for duplication of command output
# look for ">&5" below
exec 5>&1

# Parse command line arguments
RLIST=$1
[[ "$2" ]] && INPUTDIR=$2 || INPUTDIR="$VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/"
[[ "$3" ]] && ODIR=$3 || ODIR=${INPUTDIR}
[[ "$4" ]] && ID=$4 || ID=0
[[ "$5" ]] && SIMTYPE=$5 || SIMTYPE=""
[[ "$6" ]] && FORCEDATMO=$6

SIMTYPE_DEFAULT_V4="GRISU"
SIMTYPE_DEFAULT_V5="GRISU"
SIMTYPE_DEFAULT_V6="CARE_June2020"
SIMTYPE_DEFAULT_V6_REDHV="CARE_RedHV"

# Read runlist
if [ ! -f "$RLIST" ] ; then
    echo "Error, runlist $RLIST not found, exiting..."
    exit 1
fi
FILES=`cat $RLIST`

NRUNS=`cat $RLIST | wc -l ` 
echo "total number of runs to analyze: $NRUNS"
echo

# make output directory if it doesn't exist
mkdir -p $ODIR
echo -e "Output files will be written to:\n $ODIR"

# run scripts are written into this directory
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/MSCW.ANADATA"
mkdir -p $LOGDIR
echo -e "Log files will be written to:\n $LOGDIR"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.mscw_energy_sub"

TIMETAG=`date +"%s"`

#########################################
# loop over all files in files loop
for AFILE in $FILES
do
    BFILE="$INPUTDIR/$AFILE.root"
    echo "Now analysing $BFILE (ID=$ID)"

    if [ ! -e "$BFILE" ]; then
        echo "ERR: File $BFILE does not exist !!!" >> mscw.errors.log
        continue
    fi

    RUNINFO=`$EVNDISPSYS/bin/printRunParameter $BFILE -runinfo`
    EPOCH=`echo $RUNINFO | awk '{print $(1)}'`
    ATMO=${FORCEDATMO:-`echo $RUNINFO | awk '{print $(3)}'`}
    HVSETTINGS=`echo $RUNINFO | awk '{print $(4)}'`
    if [[ $ATMO == *error* ]]; then
        echo "error finding atmosphere; skipping run $BFILE"
        continue
    fi

    if [ "$SIMTYPE" == "" ]
    then
        if [ "$EPOCH" == "V4" ]
        then
            SIMTYPE_RUN="$SIMTYPE_DEFAULT_V4"
            ATMO=$[${ATMO}-40]
        elif [ "$EPOCH" == "V5" ]
        then
            SIMTYPE_RUN="$SIMTYPE_DEFAULT_V5"
            ATMO=$[${ATMO}-40]
        else
            if [ "$HVSETTINGS" == "obsLowHV" ]; then
                SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6_REDHV"
                ATMO="61"
            else
                SIMTYPE_RUN="$SIMTYPE_DEFAULT_V6"
            fi
        fi
    else
        SIMTYPE_RUN="$SIMTYPE"
    fi

    TABFILE=table-${IRFVERSION}-auxv01-${SIMTYPE_RUN}-ATM${ATMO}-${EPOCH}-GEO.root
    echo $TABFILE
    # Check that table file exists
    if [[ "$TABFILE" == `basename $TABFILE` ]]; then
        TABFILE="$VERITAS_EVNDISP_AUX_DIR/Tables/$TABFILE"
    fi
    if [ ! -f "$TABFILE" ]; then
        echo "Error, table file '$TABFILE' not found, exiting..."
        exit 1
    fi

    FSCRIPT="$LOGDIR/MSCW.data-ID$ID-$AFILE"
    rm -f $FSCRIPT.sh

    sed -e "s|TABLEFILE|$TABFILE|" \
        -e "s|RECONSTRUCTIONID|$ID|" \
        -e "s|OUTPUTDIRECTORY|$ODIR|" \
        -e "s|EVNDISPFILE|$BFILE|" $SUBSCRIPT.sh > $FSCRIPT.sh

    chmod u+x $FSCRIPT.sh
    echo $FSCRIPT.sh

    # run locally or on cluster
    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    echo "Submission command: $SUBC"
    if [[ $SUBC == *qsub* ]]; then
        JOBID=`$SUBC $FSCRIPT.sh`
        
        # account for -terse changing the job number format
        if [[ $SUBC != *-terse* ]] ; then
            echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
            JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
        fi
        
		echo "RUN $AFILE JOBID $JOBID"
        echo "RUN $AFILE SCRIPT $FSCRIPT.sh"
        if [[ $SUBC != */dev/null* ]] ; then
            echo "RUN $AFILE OLOG $FSCRIPT.sh.o$JOBID"
            echo "RUN $AFILE ELOG $FSCRIPT.sh.e$JOBID"
        fi
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.$TIMETAG.dat
        echo "RUN $AFILE OLOG $FSCRIPT.log"
    elif [[ "$SUBC" == *simple* ]] ; then
	$FSCRIPT.sh |& tee "$FSCRIPT.log"
    fi
done

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    cat $LOGDIR/runscripts.$TIMETAG.dat | $SUBC
fi

exit
