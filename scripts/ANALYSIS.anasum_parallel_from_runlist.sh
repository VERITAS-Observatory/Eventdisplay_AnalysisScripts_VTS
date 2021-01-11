#!/bin/bash
# script to analyse data files with anasum (parallel analysis) from a simple run list

# EventDisplay version
EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`

if [[ "$#" -lt 4 ]]; then
# begin help message
echo "
ANASUM parallel data analysis: submit jobs using a simple run list

ANALYSIS.anasum_parallel_from_runlist.sh <run list> <output directory> <cut set> <background model> [run parameter file] [mscw directory] [sim type] \
[radial acceptances] [force atmosphere]

required parameters:

    <run list>              simple runlist with a single run number per line
        
    <output directory>      anasum output files are written to this directory
                        
    <cut set>               hardcoded cut sets predefined in the script
                            (i.e., moderate2tel, soft2tel, hard3tel)
    
    <background model>      background model
                            (RE = reflected region, RB = ring background, IGNOREACCEPTANCE = RE without ACCEPTANCE)
    
optional parameters:

    [run parameter file]    anasum run parameter file (located in 
                            \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/;
                            default is ANASUM.runparameter)

    [mscw directory]        directory containing the mscw.root files.
			    Default: $VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION

    [sim type]              use IRFs derived from this simulation type (GRISU-SW6 or CARE_June1702)
			    Default: CARE_June1702

    [radial acceptance]     0=use external radial acceptance;
                            1=use run-wise radial acceptance (calculated from data run);
                            2=ignore radial acceptances (only for reflected region);

    [force atmosphere]	    use EAs generated with this atmospheric model (61 or 62).
			    Default: Atmosphere determined from run date for each run.				
			    Attention: Must use the same atmospere for EAs as was used for the lookup tables in the mscw_energy stage!

IMPORTANT! Run ANALYSIS.anasum_combine.sh once all parallel jobs have finished!

--------------------------------------------------------------------------------
"
#end help message
exit
fi

###########################
# IRFs
IRFVERSION=`$EVNDISPSYS/bin/mscw_energy --version | tr -d . | sed -e 's/[a-zA-Z]*$//'`
AUXVERSION="auxv01"

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RLIST=$1
ODIR=$2
CUTS=$3
BACKGND=$4
[[ "$5" ]] && RUNP=$5  || RUNP="ANASUM.runparameter"
[[ "$6" ]] && INDIR=$6 || INDIR="$VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/"
[[ "$7" ]] && SIMTYPE=$7 || SIMTYPE="DEFAULT"
METH="GEO"
[[ "$8" ]] && RACC=$8 || RACC="0"
[[ "$9" ]] && FORCEDATMO=$9 

SIMTYPE_DEFAULT_V4="GRISU"
SIMTYPE_DEFAULT_V5="GRISU"
SIMTYPE_DEFAULT_V6="CARE_June2020"
SIMTYPE_DEFAULT_V6redHV="CARE_RedHV"

# cut definitions (note: VX to be replaced later in script)
if [[ $CUTS = moderate2tel ]]; then
    CUT="NTel2-PointSource-Moderate-TMVA-BDT"
elif [[ $CUTS = soft2tel ]]; then
    CUT="NTel2-PointSource-Soft-TMVA-BDT"
elif [[ $CUTS = hard2tel ]]; then 
    CUT="NTel2-PointSource-Hard-TMVA-BDT"
elif [[ $CUTS = hard3tel ]]; then
    CUT="NTel3-PointSource-Hard-TMVA-BDT"
elif [[ $CUTS = NTel2ModeratePre ]]; then
    CUT="NTel2-PointSource-Moderate-TMVA-Preselection"
elif [[ $CUTS = NTel2SoftPre ]]; then
    CUT="NTel2-PointSource-Soft-TMVA-Preselection"
else
    echo "ERROR: unknown cut definition: $CUTS"
    exit 1
fi
CUTFILE="ANASUM.GammaHadron-Cut-${CUT}.dat"
EFFAREA="effArea-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUT}-${METH}-VX-ATMXX-TX.root"

# remove PointSource and ExtendedSource string from cut file name for radial acceptances names
if [[ $CUT == *PointSource-* ]] ; then
    CUTRADACC=${CUT/-PointSource-/"-"}
    echo $CUTRACACC
elif [[ $CUT == *ExtendedSource-* ]]; then
    CUTRADACC=${CUT/-ExtendedSource-/"-"}
    echo $CUTRADACC
fi

RADACC="radialAcceptance-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUTRADACC}-${METH}-VX-TX.root"
# START TEMPORARY (TESTS, comment)
# EFFAREA="IGNOREEFFECTIVEAREA"
# END TEMPORARY

echo "$CUTFILE"
echo "$EFFAREA"
echo "$RADACC"

# background model parameters
if [[ "$BACKGND" == *RB* ]]; then
    BM="RB"
    BMPARAMS="0.6 20"
    if [[ "$RACC" == "2" ]]; then
        echo "Error, Cannot use RB without radial acceptances:"
        echo "Specify an acceptance (external=0, runwise=1) or use RE."
        exit 1
    fi
elif [[ "$BACKGND" == *IGNOREACCEPTANCE* ]]; then
    BM="RE"
    BMPARAMS="0.1 2 6"
    RADACC="IGNOREACCEPTANCE"
elif [[ "$BACKGND" == *RE* ]]; then
    BM="RE"
    BMPARAMS="0.1 2 6"
else
    echo "ERROR: unknown background model: $BACKGND"
    echo "Allowed values are: RE, RB"
    exit 1
fi

# Check that run list exists
if [[ ! -f "$RLIST" ]]; then
    echo "Error, simple runlist $RLIST not found, exiting..."
    exit 1
fi

# Check that run parameter file exists
if [[ "$RUNP" == `basename $RUNP` ]]; then
    RUNP="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNP"
fi
if [ ! -f "$RUNP" ]; then
    echo "Error, anasum run parameter file not found, exiting..."
    echo "(searched for $RUNP)"
    exit 1
fi

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/$DATE/ANASUM.ANADATA"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# output directory for anasum products
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"

#########################################
# make anasum run list
ANARUNLIST="$ODIR/$CUTS.anasum.dat"
rm -f "$ANARUNLIST"
echo "anasum run list: $ANARUNLIST"

# run list header
if [[ $EDVERSION = "v4"* ]]; then
    echo "* VERSION 6" >> "$ANARUNLIST"
else
    echo "* VERSION 7" >> "$ANARUNLIST"
fi
echo "" >> "$ANARUNLIST"

RUNS=`cat "$RLIST"`

# loop over all runs
for RUN in ${RUNS[@]}; do
    # get array epoch, atmosphere and telescope combination for this run
    if [ ! -e "$INDIR/$RUN.mscw.root" ]; then
        echo "error: mscw file not found: $INDIR/$RUN.mscw.root"
        continue
    fi
    RUNINFO=`"$EVNDISPSYS"/bin/printRunParameter "$INDIR/$RUN.mscw.root" -runinfo`
    EPOCH=`echo "$RUNINFO" | awk '{print $(1)}'`
    MAJOREPOCH=`echo $RUNINFO | awk '{print $(2)}'`
    ATMO=${FORCEDATMO:-`echo $RUNINFO | awk '{print $(3)}'`}
    if [[ $ATMO == *error* ]]; then
       echo "error finding atmosphere; skipping run $RUN"
       continue
    fi
    OBSL=$(echo $RUNINFO | awk '{print $4}')
    TELTOANA=`echo $RUNINFO | awk '{print "T"$(5)}'`
    # V4 and V5: grisu sims with ATM21/22
    if [[ $EPOCH == *"V4"* ]] || [[ $EPOCH == *"V5"* ]]; then
        ATMO=${ATMO/6/2}
    fi
    if [[ $SIMTYPE == "DEFAULT" ]]; then
        if [[ $EPOCH == *"V4"* ]]; then
            REPLACESIMTYPEEff=${SIMTYPE_DEFAULT_V4}
            REPLACESIMTYPERad=${SIMTYPE_DEFAULT_V4}
        elif [[ $EPOCH == *"V5"* ]]; then
            REPLACESIMTYPEEff=${SIMTYPE_DEFAULT_V5}
            REPLACESIMTYPERad=${SIMTYPE_DEFAULT_V5}
        elif [[ $EPOCH == *"V6"* ]] && [[ $OBSL == "obsLowHV" ]]; then
            REPLACESIMTYPEEff=${SIMTYPE_DEFAULT_V6redHV}
            REPLACESIMTYPERad=${SIMTYPE_DEFAULT_V6}
        else
            REPLACESIMTYPEEff=${SIMTYPE_DEFAULT_V6}
            REPLACESIMTYPERad=${SIMTYPE_DEFAULT_V6}
        fi
     else
        REPLACESIMTYPEEff=${SIMTYPE}
        REPLACESIMTYPERad=${SIMTYPE}
     fi

    echo "RUN $RUN at epoch $EPOCH and atmosphere $ATMO (Telescopes $TELTOANA SIMTYPE $REPLACESIMTYPEEff $REPLACESIMTYPERad)"
    echo "File $INDIR/$RUN.mscw.root"

    # do string replacements
    EFFAREARUN=${EFFAREA/VX/$EPOCH}
    EFFAREARUN=${EFFAREARUN/TX/$TELTOANA}
    EFFAREARUN=${EFFAREARUN/XX/$ATMO}
    EFFAREARUN=${EFFAREARUN/SX/$REPLACESIMTYPEEff}

    if [[ ${RACC} == "1" ]]; then
        echo "run-wise radical acceptances: "
        RADACCRUN="$ODIR/$RUN.anasum.radialAcceptance.root"
        echo "   $RADACCRUN"
    elif [[ ${RACC} == "0" ]]; then
        echo "external radial acceptances: "
        RADACCRUN=${RADACC/VX/$MAJOREPOCH}
        RADACCRUN=${RADACCRUN/TX/$TELTOANA}
        RADACCRUN=${RADACCRUN/SX/$REPLACESIMTYPERad}
    else
        echo "Ignore acceptances: "
        RADACCRUN="IGNOREACCEPTANCE"
    fi
    
    # write line to anasum input file
    if [[ $EDVERSION = "v4"* ]]; then
        echo "* $RUN $RUN 0 $CUTFILE $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> $ANARUNLIST
        echo "* $RUN $RUN 0 $CUTFILE $BM $EFFAREARUN $BMPARAMS $RADACCRUN"
    # v5x: cuts are read from the effective area file
    else
        echo "* $RUN $RUN 0 $BM $EFFAREARUN $BMPARAMS $RADACCRUN" >> "$ANARUNLIST"
        echo "* $RUN $RUN 0 $BM $EFFAREARUN $BMPARAMS $RADACCRUN"
    fi
done

# submit the job
SUBSCRIPT=$(dirname "$0")"/ANALYSIS.anasum_parallel"
$SUBSCRIPT.sh "$ANARUNLIST" "$INDIR" "$ODIR" "$RUNP" "${RACC}"

exit
