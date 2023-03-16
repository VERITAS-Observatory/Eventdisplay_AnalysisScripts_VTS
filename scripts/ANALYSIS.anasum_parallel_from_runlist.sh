#!/bin/bash
# script to analyse data files with anasum (parallel analysis) from a simple run list

EDVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d .`
# qsub parameters
h_cpu=0:59:00; h_vmem=4000M; tmpdir_size=1G

if [[ "$#" -lt 4 ]]; then
# begin help message
echo "
ANASUM parallel data analysis: submit jobs using a simple run list

ANALYSIS.anasum_parallel_from_runlist.sh <run list> <output directory> <cut set> <background model> \
[run parameter file] [mscw directory] [sim type] \
[radial acceptances] [force atmosphere]

required parameters:

    <run list>              simple runlist with a single run number per line
        
    <output directory>      anasum output files are written to this directory
                        
    <cut set>               hardcoded cut sets predefined in the script
                            (i.e., moderate2tel, soft2tel, hard3tel)
                            (for BDT preparation: NTel2ModeratePre, NTel2SoftPre, NTel3HardPre)
    
    <background model>      background model
                            (RE = reflected region, RB = ring background, 
                            IGNOREACCEPTANCE = RE without ACCEPTANCE,
                            IGNOREIRF = RE without ACCEPTANCE/EFFAREA)
    
optional parameters:

    [run parameter file]    anasum run parameter file (located in 
                            \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/;
                            default is ANASUM.runparameter)

    [mscw directory]        directory containing the mscw.root files.
			    Default: $VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION

    [sim type]              use IRFs derived from this simulation type (GRISU-SW6 or CARE_June2020)
			    Default: CARE_June2020

    [radial acceptance]     0=use external radial acceptance;
                            1=use run-wise radial acceptance (calculated from data run);
                            2=ignore radial acceptances (only for reflected region);

    [force atmosphere]	    use EAs generated with this atmospheric model (61 or 62).
			    Default: Atmosphere determined from run date for each run.				
			    Attention: Must use the same atmospere for EAs as was used for the lookup tables in the mscw_energy stage!

Run ANALYSIS.anasum_combine.sh once all parallel jobs have finished!

--------------------------------------------------------------------------------
"
#end help message
exit
fi

###########################
# IRFs
IRFVERSION=`$EVNDISPSYS/bin/anasum --version | tr -d . | sed -e 's/[a-zA-Z]*$//'`
AUXVERSION="auxv01"

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RUNLIST=$1
ODIR=$2
CUTS=$3
BACKGND=$4
[[ "$5" ]] && RUNP=$5  || RUNP="ANASUM.runparameter"
[[ "$6" ]] && INDIR=$6 || INDIR="$VERITAS_USER_DATA_DIR/analysis/Results/$EDVERSION/"
[[ "$7" ]] && SIMTYPE=$7 || SIMTYPE="DEFAULT"
[[ "$8" ]] && RACC=$8 || RACC="0"
[[ "${9}" ]] && FORCEDATMO=${9}

ANATYPE="AP"
DISPBDT="1"
if [[ ! -z  $VERITAS_ANALYSIS_TYPE ]]; then
   ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
   if [[ ${VERITAS_ANALYSIS_TYPE} != *"DISP"* ]]; then
      DISPBDT="0"
   fi
fi
echo $VERITAS_ANALYSIS_TYPE $ANATYPE $DISPBDT

# short-cuts for gamma/hadron cuts (note: VX to be replaced later in script)
if [[ $CUTS = "moderate2tel" ]] || [[ $CUTS = "BDTmoderate2tel" ]]; then
    CUT="NTel2-PointSource-Moderate-TMVA-BDT"
elif [[ $CUTS = "soft2tel" ]] || [[ $CUTS = "BDTsoft2tel" ]]; then
    CUT="NTel2-PointSource-Soft-TMVA-BDT"
elif [[ $CUTS = "soft2tel2" ]] || [[ $CUTS = "BDTsoft2tel2" ]]; then
    CUT="NTel2-PointSource-Soft2-TMVA-BDT"
elif [[ $CUTS = "hard3tel" ]] || [[ $CUTS = "BDThard3tel" ]]; then
    CUT="NTel3-PointSource-Hard-TMVA-BDT"
elif [[ $CUTS = "moderatebox" ]]; then
    CUT="NTel2-PointSource-Moderate"
elif [[ $CUTS = "softbox" ]]; then
    CUT="NTel2-PointSource-Soft"
elif [[ $CUTS = "supersoft" ]]; then
    CUT="NTel2-PointSource-SuperSoft"
elif [[ $CUTS = "opensoft" ]]; then
    CUT="NTel2-PointSource-SuperSoftOpen"
elif [[ $CUTS = NTel2ModeratePre ]]; then
    CUT="NTel2-PointSource-Moderate-TMVA-Preselection"
elif [[ $CUTS = NTel2SoftPre ]]; then
    CUT="NTel2-PointSource-Soft-TMVA-Preselection"
elif [[ $CUTS = NTel3HardPre ]]; then
    CUT="NTel3-PointSource-Hard-TMVA-Preselection"
elif [[ $CUTS = NTel2Pre ]]; then
    CUT="NTel2-PointSource-TMVA-BDT-Preselection"
elif [[ $CUTS = NTel3Pre ]]; then
    CUT="NTel3-PointSource-TMVA-BDT-Preselection"
elif [[ $CUTS = "BDTExtended025moderate2tel" ]]; then
    CUT="NTel2-Extended025-Moderate-TMVA-BDT"
elif [[ $CUTS = "BDTExtended050moderate2tel" ]]; then
    CUT="NTel2-Extended050-Moderate-TMVA-BDT"
else
    echo "ERROR: unknown cut definition: $CUTS"
    exit 1
fi
CUTFILE="ANASUM.GammaHadron-Cut-${CUT}.dat"

# remove PointSource and ExtendedSource string from cut file name for radial acceptances names
if [[ $CUT == *PointSource-* ]] ; then
    CUTRADACC=${CUT/-PointSource-/"-"}
    echo $CUTRACACC
elif [[ $CUT == *"Extended"* ]]; then
    CUTRADACC=${CUT/-PointSource-/"-"}
elif [[ $CUT == *ExtendedSource-* ]]; then
    CUTRADACC=${CUT/-ExtendedSource-/"-"}
    echo $CUTRADACC
fi

if [[ $DISPBDT == "1" ]]; then
    EFFAREA="effArea-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUT}-${ANATYPE}-DISP-VX-ATMXX-TX.root"
    RADACC="radialAcceptance-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUTRADACC}-${ANATYPE}-DISP-VX-TX.root"
else
    EFFAREA="effArea-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUT}-${ANATYPE}-VX-ATMXX-TX.root"
    RADACC="radialAcceptance-${IRFVERSION}-${AUXVERSION}-SX-Cut-${CUTRADACC}-${ANATYPE}-VX-TX.root"
fi

echo "$CUTFILE"
echo "$EFFAREA"
echo "$RADACC"

# background model parameters
if [[ "$BACKGND" == *RB* ]]; then
    BM="RB"
    BMPARAMS="0.6 20"
    if [[ $CUT == *"Extended"* ]]; then
        BMPARAMS="1.0 3"
    fi
    if [[ "$RACC" == "2" ]]; then
        echo "Error, Cannot use RB without radial acceptances:"
        echo "Specify an acceptance (external=0, runwise=1) or use RE."
        exit 1
    fi
elif [[ "$BACKGND" == "RE" ]] || [[ "$BACKGND" == *IGNOREACCEPTANCE* ]] || [[ "$BACKGND" == *IGNOREIRF* ]]; then
    BM="RE"
    BMPARAMS="0.1 2 6"
    # ignore always acceptances in reflected region model
    if [[ "$BACKGND" == "RE" ]]; then
        BACKGND="IGNOREACCEPTANCE"
    fi
else
    echo "ERROR: unknown background model: $BACKGND"
    echo "Allowed values are: RE, RB"
    exit 1
fi

# Check that run list exists
if [[ ! -f "$RUNLIST" ]]; then
    echo "Error, simple runlist $RUNLIST not found, exiting..."
    exit 1
fi

# Check that run parameter file exists
if [[ "$RUNP" == `basename $RUNP` ]]; then
    RUNP="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNP"
fi
if [[ ! -f "$RUNP" ]]; then
    echo "Error, anasum run parameter file not found, exiting..."
    echo "(searched for $RUNP)"
    exit 1
fi

# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$VERITAS_USER_LOG_DIR/submit.ANASUM.SIMPLE-${DATE}-$(uuidgen)"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p "$LOGDIR"

# output directory for anasum products
echo -e "Output files will be written to:\n $ODIR"
mkdir -p "$ODIR"

# Job submission script
SUBSCRIPT=$( dirname "$0" )"/helper_scripts/ANALYSIS.anasum_sub"
TIMETAG=`date +"%s"`

# directory schema
getNumberedDirectory()
{
    TRUN="$1"
    if [[ ${TRUN} -lt 100000 ]]; then
        ODIR="${INDIR}/${TRUN:0:1}/"
    else
        ODIR="${INDIR}/${TRUN:0:2}/"
    fi
    echo ${ODIR}
}

# loop over all runs
RUNS=`cat "$RUNLIST"`
for RUN in ${RUNS[@]}; do
    TMPINDIR="$INDIR"
    if [ ! -e "$TMPINDIR/$RUN.mscw.root" ]; then
        TMPINDIR=$(getNumberedDirectory $RUN)
        if [ ! -e "$TMPINDIR/$RUN.mscw.root" ]; then
            echo "error: mscw file not found: $TMPINDIR/$RUN.mscw.root (also not found in directory above)"
            continue
        fi
    fi

    # prepare run scripts
    FSCRIPT="$LOGDIR/qsub_analyse-$DATE-RUN$RUN-$(date +%s)"
    echo "Run script written to $FSCRIPT"

    sed -e "s|FILELIST|NOTDEFINED|" \
        -e "s|DATADIR|$TMPINDIR|"        \
        -e "s|OUTDIR|$ODIR|"          \
        -e "s|OUTNAME|$RUN.anasum|"        \
        -e "s|RUNNNNN|$RUN|"          \
        -e "s|RAAACCC|$RACC|"          \
        -e "s|BBM|$BM|" \
        -e "s|MBMPARAMS|$BMPARAMS|" \
        -e "s|CCUTFILE|$CUTFILE|" \
        -e "s|EEEFFAREARUN|$EFFAREA|" \
        -e "s|RRADACCRUN|$RADACC|" \
        -e "s|SPSIMTYPE|$SIMTYPE|" \
        -e "s|BBACKGND|$BACKGND|" \
        -e "s|RUNPARAM|$RUNP|" "$SUBSCRIPT.sh" > "$FSCRIPT.sh"

    chmod u+x "$FSCRIPT.sh"
    
    # run locally or on cluster
    SUBC=`$( dirname "$0" )/helper_scripts/UTILITY.readSubmissionCommand.sh`
    SUBC=`eval "echo \"$SUBC\""`
    if [[ $SUBC == *"ERROR"* ]]; then
        echo "$SUBC"
        exit
    fi
    if [[ $SUBC == *qsub* ]]; then
        JOBID=`$SUBC $FSCRIPT.sh`
        # account for -terse changing the job number format
        if [[ $SUBC != *-terse* ]] ; then
            echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
            JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
        fi
    elif [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
	elif [[ $SUBC == *sbatch* ]]; then
        $SUBC $FSCRIPT.sh
    elif [[ $SUBC == *parallel* ]]; then
        echo "$FSCRIPT.sh &> $FSCRIPT.log" >> "$LOGDIR/runscripts.$TIMETAG.dat"
    elif [[ "$SUBC" == *simple* ]] ; then
	    "$FSCRIPT.sh" |& tee "$FSCRIPT.log"
	fi
done

# submit all condor jobs at once
if [[ $SUBC == *condor* ]]; then
    $EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit
fi

# Execute all FSCRIPTs locally in parallel
if [[ $SUBC == *parallel* ]]; then
    cat "$LOGDIR/runscripts.$TIMETAG.dat" | $SUBC
fi

exit
