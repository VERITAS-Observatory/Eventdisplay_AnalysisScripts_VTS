#!/bin/bash
# train BDTs for gamma/hadron separation
#
# note the large amount of hardwired parameters in this scripts:
# - zenith angles to be trained
# - training at wobble offsets 0.5 deg only
# - fixed of NSB levels (adapted to stdHV settings)
#
# Performance optimizations (Nov 2025):
# - Read runparameter file once instead of multiple greps
# - Batch file writes with output grouping {...} >> file
# - Replace basename/get_run_prefix subprocesses with awk/parameter expansion
# - Use nullglob for safe file globbing without ls
#

h_cpu=11:59:59; h_vmem=4000M; tmpdir_size=24G
# EventDisplay version
EDVERSION=$(cat $VERITAS_EVNDISP_AUX_DIR/IRFVERSION)

if [ $# -lt 7 ]; then
echo "
TMVA (BDT) training for gamma/hadron separation: submit jobs from a TMVA runparameter file

IRF.trainTMVAforGammaHadronSeparation.sh <background file directory> <TMVA runparameter file> <output directory> <output file name> <sim type> <epoch> <atmosphere>

required parameters:

    <background file directory>     directory with background training (mscw) files

    <TMVA runparameter file>        TMVA runparameter file with basic options (incl. whole range of
	                                energy and zenith angle bins) and full path

    <output directory>              BDT files are written to this directory

    <output file name>              name of output file e.g. BDT

    <sim type>                      simulation type
                                    (e.g. GRISU, CARE_June2020, CARE_RedHV, CARE_UV)

    <epoch>                         array epoch e.g. V4, V5,
                                    V6 epochs: e.g., \"V6_2012_2013a V6_2012_2013b\"

    <atmosphere>                    atmosphere model(s) (61 = winter, 62 = summer)

--------------------------------------------------------------------------------
"
exit
fi

# Run init script
if [ ! -n "$EVNDISP_APPTAINER" ]; then
    bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
fi
[[ $? != "0" ]] && exit 1

BDIR="$1"
RUNPAR="$2"
ODIR="$3"
ONAME="$4"
SIMTYPE="$5"
EPOCH="$6"
ATM="$7"

RECID="0"
PARTICLE_TYPE="gamma"
UUID="${12:-$(date +"%y%m%d")-$(uuidgen)}"

echo "Background file directory: $BDIR"
echo "Runparameters: $RUNPAR"
echo "Simulation type: $SIMTYPE"

# Fixed list of NSB levels; redHV needs attention
if [[ ${SIMTYPE} == *"RedHV"* ]]; then
    echo "Fixed NSB levels not suitable for RedHV trainging"
    exit 1
fi

DISPBDT=""
ANATYPE="AP"
if [[ ! -z $VERITAS_ANALYSIS_TYPE ]]; then
    ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
    if [[ ${VERITAS_ANALYSIS_TYPE} == *"DISP"* ]]; then
        DISPBDT="_DISP"
    fi
fi

# Check that list of background file directory exists
if [[ ! -d "$BDIR" ]]; then
    echo "Error, directory with background files $BDIR not found, exiting..."
    exit 1
fi

# Check that TMVA run parameter file exists
if [[ "$RUNPAR" == `basename $RUNPAR` ]]; then
    RUNPAR="$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/$RUNPAR"
fi
if [[ ! -f "$RUNPAR" ]]; then
    echo "Error, TMVA run parameter file $RUNPAR not found, exiting..."
    exit 1
fi

RXPAR=`basename $RUNPAR .runparameter`
echo "Original TMVA run parameter file: $RXPAR.runparameter "

LOGDIR="$ODIR/TMVA.ANADATA.${UUID}"
echo "Output: $ODIR"
echo "Logs: $LOGDIR"
mkdir -p $LOGDIR
mkdir -p $ODIR

#####################################
# Read runparameter file once for efficiency
RUNPAR_CONTENT=$(cat "$RUNPAR")

#####################################
# energy bins
if echo "$RUNPAR_CONTENT" | grep -q "^* ENERGYBINS"; then
    ENBINS=$(echo "$RUNPAR_CONTENT" | grep "^* ENERGYBINS" | sed -e 's/* ENERGYBINS//' | sed -e 's/ /\n/g')
    declare -a EBINARRAY=( $ENBINS ) #convert to array
    count1=1
    NENE=$((${#EBINARRAY[@]}-$count1)) #get number of bins
    for (( i=0; i < $NENE; i++ ))
    do
        EBINMIN[$i]=${EBINARRAY[$i]}
        EBINMAX[$i]=${EBINARRAY[$i+1]}
    done
else
    ENBINS=$(echo "$RUNPAR_CONTENT" | grep "^* ENERGYBINEDGES" | sed -e 's/* ENERGYBINEDGES//' | sed -e 's/ /\n/g')
    declare -a EBINARRAY=( $ENBINS ) #convert to array
    count1=1
    NENE=$((${#EBINARRAY[@]}-$count1)) #get number of bins
    z="0"
    for (( i=0; i < $NENE; i+=2 ))
    do
        EBINMIN[$z]=${EBINARRAY[$i]}
        EBINMAX[$z]=${EBINARRAY[$i+1]}
        let "z = ${z} + 1"
    done
    NENE=$((${#EBINMAX[@]}))
fi

#####################################
# zenith angle bins
ZEBINS=$(echo "$RUNPAR_CONTENT" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-$count1)) #get number of bins

#####################################
# zenith angle bins of MC simulation files
ZENITH_ANGLES=( 20 30 35 40 45 50 55 60 )


####################################
# Run prefix
get_run_prefix()
{
    RUNN="${1%%.*}"

    if [[ ${RUNN} -lt 100000 ]]; then
        echo "${RUNN:0:1}"
    else
        echo "${RUNN:0:2}"
    fi
}

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.trainTMVAforGammaHadronSeparation_sub"

###############################################################
# loop over all energy bins and submit a job for each bin
for (( i=0; i < $NENE; i++ ))
do
   echo "==========================================================================="
   echo " "
   echo "Energy Bin: $(($i+$count1)) of $NENE: ${EBINMIN[$i]} to ${EBINMAX[$i]} (in log TeV)"
##############################################
# loop over all zenith angle bins
   for (( j=0; j < $NZEW; j++ ))
   do
      echo "---------------------------------------------------------------------------"
      echo "Zenith Bin: $(($j+$count1)) of $NZEW: ${ZEBINARRAY[$j]} to ${ZEBINARRAY[$j+1]} (deg)"

      # updating the run parameter file for each parameter space
      RFIL=$ODIR/$RXPAR"_$i""_$j"
      echo "TMVA Runparameter file: $RFIL.runparameter"
      rm -f $RFIL

      echo "* ENERGYBINS ${EBINMIN[$i]} ${EBINMAX[$i]}" > $RFIL.runparameter
      echo "* ZENBINS  ${ZEBINARRAY[$j]} ${ZEBINARRAY[$j+1]}" >> $RFIL.runparameter
      echo "$RUNPAR_CONTENT" | grep "^\*" | grep -v ENERGYBINS | grep -v ENERGYBINEDGES | grep -v ZENBINS | grep -v OUTPUTFILE | grep -v SIGNALFILE | grep -v BACKGROUNDFILE | grep -v MCXYOFF >> $RFIL.runparameter

      nTrainSignal=200000
      nTrainBackground=200000

      echo "* PREPARE_TRAINING_OPTIONS SplitMode=Random:!V:nTrain_Signal=$nTrainSignal:nTrain_Background=$nTrainBackground::nTest_Signal=$nTrainSignal:nTest_Background=$nTrainBackground" >> $RFIL.runparameter

      echo "* OUTPUTFILE ODIR ${ONAME}_${i}_${j}" >> $RFIL.runparameter

      echo "#######################################################################################" >> $RFIL.runparameter
      # signal and background files (depending on on-axis or cone data set)
      # Collect all signal files first, then write in one batch
      {
          for ATMX in $ATM; do
              SDIR="$VERITAS_IRFPRODUCTION_DIR/$EDVERSION/$ANATYPE/$SIMTYPE/${EPOCH}_ATM${ATMX}_${PARTICLE_TYPE}/MSCW_RECID${RECID}${DISPBDT}"
              echo "Signal input directory: $SDIR"
              if [[ ! -d $SDIR ]]; then
                  echo -e "Error, could not locate directory of simulation files (input). Locations searched:\n $SDIR"
                  exit 1
              fi
              if [[ ${SIMTYPE:0:5} = "GRISU" ]]; then
                  for (( l=0; l < ${#ZENITH_ANGLES[@]}; l++ ))
                  do
                      if (( $(echo "${ZEBINARRAY[$j]} <= ${ZENITH_ANGLES[$l]}" | bc ) && $(echo "${ZEBINARRAY[$j+1]} >= ${ZENITH_ANGLES[$l]}" | bc ) ));then
                          if (( "${ZENITH_ANGLES[$l]}" != "00" && "${ZENITH_ANGLES[$l]}" != "60" && "${ZENITH_ANGLES[$l]}" != "65" )); then
                              # Use parameter expansion to avoid basename subprocess calls
                              shopt -s nullglob
                              for arg in "$SDIR"/${ZENITH_ANGLES[$l]}deg_0.5wob_NOISE{100,150,200,250,325,425,550}.mscw.root; do
                                  echo "* SIGNALFILE SIMDIR/${arg##*/}"
                              done
                              shopt -u nullglob
                          fi
                      fi
                  done
              else
                  for (( l=0; l < ${#ZENITH_ANGLES[@]}; l++ ))
                  do
                      if (( $(echo "${ZEBINARRAY[$j]} <= ${ZENITH_ANGLES[$l]}" | bc ) && $(echo "${ZEBINARRAY[$j+1]} >= ${ZENITH_ANGLES[$l]}" | bc ) ));then
                          if (( "${ZENITH_ANGLES[$l]}" != "00" && "${ZENITH_ANGLES[$l]}" != "60" && "${ZENITH_ANGLES[$l]}" != "65" )); then
                              # Use parameter expansion to avoid basename subprocess calls
                              shopt -s nullglob
                              for arg in "$SDIR"/${ZENITH_ANGLES[$l]}deg_0.5wob_NOISE{100,160,200,250,350,450}.mscw.root; do
                                  echo "* SIGNALFILE SIMDIR/${arg##*/}"
                              done
                              shopt -u nullglob
                          fi
                      fi
                  done
              fi
          done
      } >> $RFIL.runparameter
      echo "#######################################################################################" >> $RFIL.runparameter
      BLIST="$ODIR/BackgroundRunlist_Ze${j}.list"
      rm -f ${BLIST}
      if [[ ! -d "${BDIR}/Ze_${j}" ]]; then
          echo "Error, directory with background files ${BDIR}/Ze_${j} not found, exiting..."
          exit 1
      fi
      # Optimized background file listing using awk instead of subshell per file
      # This replaces the get_run_prefix() function call for each file
      find ${BDIR}/Ze_${j} -name "*.root" -printf "%f\n" | sort -n | \
      awk '{
          filename = $0;
          # Remove extension to get run number (equivalent to ${1%%.*})
          sub(/\..*$/, "", $0);
          runn = $0;
          # Check if run number < 100000 (length check)
          if (runn < 100000) {
              prefix = substr(runn, 1, 1);
          } else {
              prefix = substr(runn, 1, 2);
          }
          print "* BACKGROUNDFILE DDIR/" prefix "/" filename;
      }' >> "$RFIL.runparameter"
      # expect training files to be from pre-processing directory
      BCKFILEDIR="$VERITAS_PREPROCESSED_DATA_DIR/$ANATYPE/mscw"

      FSCRIPT=$LOGDIR/$ONAME"_$EPOCH""_$i""_$j"
      sed -e "s|RUNPARAM|$RFIL|"  \
          -e "s|MCDIRECTORY|$SDIR|" \
          -e "s|DATADIRECTORY|$BCKFILEDIR|" \
          -e "s|OUTPUTDIR|${ODIR}|" \
          -e "s|OUTNAME|$ODIR/$ONAME_${i}_${j}|" $SUBSCRIPT.sh > $FSCRIPT.sh

      chmod u+x $FSCRIPT.sh
      echo $FSCRIPT.sh

      # run locally or on cluster
      SUBC=$($(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh)
      SUBC=$(eval "echo \"$SUBC\"")
      if [[ $SUBC == *"ERROR"* ]]; then
            echo $SUBC
            exit
      fi
      if [[ $SUBC == *qsub* ]]; then
         JOBID=$($SUBC $FSCRIPT.sh)
         # account for -terse changing the job number format
         if [[ $SUBC != *-terse* ]] ; then
            echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
            JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
         fi
         echo "JOBID:  $JOBID"
      elif [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
        echo
        echo "-------------------------------------------------------------------------------"
        echo "Job submission using HTCondor - run the following script to submit jobs at once:"
        echo "$EVNDISPSCRIPTS/helper_scripts/submit_scripts_to_htcondor.sh ${LOGDIR} submit"
        echo "-------------------------------------------------------------------------------"
        echo
      elif [[ $SUBC == *sbatch* ]]; then
            $SUBC $FSCRIPT.sh
      elif [[ $SUBC == *parallel* ]]; then
         echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
         cat $LOGDIR/runscripts.dat | $SUBC
      elif [[ "$SUBC" == *simple* ]] ; then
         "$FSCRIPT.sh" | tee "$FSCRIPT.log"
      fi
   done
done
