#!/bin/bash
# script to train BDTs with TMVA
#
# note the large amount of hardwired parameters in this scripts
# dependence especially on the type of simulations and
# available zenith / NSB bins
#

h_cpu=11:59:59; h_vmem=4000M; tmpdir_size=24G

if [[ $# -lt 7 ]]; then
# begin help message
echo "
TMVA training of BDT: submit jobs from a TMVA runparameter file

IRF.trainTMVAforGammaHadronSeparation.sh <background file directory> <TMVA runparameter file> <output directory> <output file name> <sim type>
 <epoch> <atmosphere>

required parameters:

    <background file directory>     directory with background training (mscw) files
    
    <TMVA runparameter file>        TMVA runparameter file with basic options (incl. whole range of 
	                                energy and zenith angle bins) and full path
    
    <output directory>              BDT files are written to this directory
    
    <output file name>              name of output file e.g. BDT  

    <sim type>                      original VBF file simulation type (e.g. GRISU, CARE)

    <epoch>                         array epoch e.g. V4, V5, V6
                                    default: \"V6\"

    <atmosphere>                    atmosphere model(s) (61 = winter, 62 = summer)
                                    default: \"61\"

additional info:

    energy and zenith angle bins should be indicated in the runparameter file with basic options
--------------------------------------------------------------------------------
"
#end help message
exit
fi
echo " "
# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
BDIR=$1
RUNPAR=$2
ODIR=$3
ONAME=$4
[[ "$5" ]] && SIMTYPE=$5 || SIMTYPE="CARE_June2020"
echo "Background file directory: $BDIR"
echo "Runparameters: $RUNPAR"
echo "Output dir: $ODIR"
echo "Simulation type: $SIMTYPE"
[[ "$6" ]] && EPOCH=$6 || EPOCH="V6"
[[ "$7" ]] && ATM=$7 || ATM="61"
RECID="0"
PARTICLE_TYPE="gamma"
# evndisplay version
IRFVERSION=`$EVNDISPSYS/bin/trainTMVAforGammaHadronSeparation --version | tr -d .| sed -e 's/[a-Z]*$//'`

if [[ -z $VERITAS_ANALYSIS_TYPE ]]; then
    VERITAS_ANALYSIS_TYPE="AP"
fi

# Check that list of background files exists
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

# output directory
echo -e "Output files will be written to:\n $ODIR"
mkdir -p $ODIR

#####################################
# energy bins
ENBINS=$( cat "$RUNPAR" | grep "^* ENERGYBINS 1" | sed -e 's/* ENERGYBINS 1//' | sed -e 's/ /\n/g')
declare -a EBINARRAY=( $ENBINS ) #convert to array
count1=1
NENE=$((${#EBINARRAY[@]}-$count1)) #get number of bins

#####################################
# zenith angle bins
ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-$count1)) #get number of bins

#####################################
# zenith angle bins of MC simulation files
ZENITH_ANGLES=( 20 30 35 40 45 50 55 60 )

#####################################
# directory for run scripts
DATE=`date +"%y%m%d"`
LOGDIR="$ODIR/$DATE/TMVA.ANADATA"
echo -e "Log files will be written to:\n $LOGDIR"
mkdir -p $LOGDIR

# Job submission script
SUBSCRIPT=$(dirname "$0")"/helper_scripts/IRF.trainTMVAforGammaHadronSeparation_sub"

###############################################################
# loop over all energy bins and submit a job for each bin
for (( i=0; i < $NENE; i++ ))
do
   echo "==========================================================================="
   echo " "
   echo "Energy Bin: $(($i+$count1)) of $NENE: ${EBINARRAY[$i]} to ${EBINARRAY[$i+1]} (in log TeV)"
##############################################
# loop over all zenith angle bins
   for (( j=0; j < $NZEW; j++ ))
   do
      echo "---------------------------------------------------------------------------"
      echo "Zenith Bin: $(($j+$count1)) of $NZEW: ${ZEBINARRAY[$j]} to ${ZEBINARRAY[$j+1]} (deg)"
      
      # copy run parameter file with basic options to output directory
      # cp -v -f $RUNPAR $ODIR

      # updating the run parameter file for each parameter space
      RFIL=$ODIR/$RXPAR"_$i""_$j"
      echo "TMVA Runparameter file: $RFIL.runparameter"
      rm -f $RFIL
      
      echo "* ENERGYBINS 1 ${EBINARRAY[$i]} ${EBINARRAY[$i+1]}" > $RFIL.runparameter
      echo "* ZENBINS  ${ZEBINARRAY[$j]} ${ZEBINARRAY[$j+1]}" >> $RFIL.runparameter
      grep "*" $RUNPAR | grep -v ENERGYBINS | grep -v ZENBINS | grep -v OUTPUTFILE | grep -v SIGNALFILE | grep -v BACKGROUNDFILE | grep -v MCXYOFF >> $RFIL.runparameter
    
      nTrainSignal=200000
      nTrainBackground=200000

      echo "* PREPARE_TRAINING_OPTIONS SplitMode=Random:!V:nTrain_Signal=$nTrainSignal:nTrain_Background=$nTrainBackground::nTest_Signal=$nTrainSignal:nTest_Background=$nTrainBackground" >> $RFIL.runparameter

      echo "* OUTPUTFILE $ODIR/ ${ONAME}_${i}_${j}" >> $RFIL.runparameter

      echo "#######################################################################################" >> $RFIL.runparameter
      # signal and background files (depending on on-axis or cone data set)
      for ATMX in $ATM; do
          SDIR="$VERITAS_IRFPRODUCTION_DIR/$IRFVERSION/$VERITAS_ANALYSIS_TYPE/$SIMTYPE/${EPOCH}_ATM${ATMX}_${PARTICLE_TYPE}/MSCW_RECID${RECID}"
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
                          SIGNALLIST=`ls -1 $SDIR/${ZENITH_ANGLES[$l]}deg_0.5wob_NOISE{100,150,200,250,325,425,550}.mscw.root`
                          for arg in $SIGNALLIST
                          do
                              echo "* SIGNALFILE $arg" >> $RFIL.runparameter
                          done
                      fi
                  fi
              done
          else
              for (( l=0; l < ${#ZENITH_ANGLES[@]}; l++ ))
              do
                  if (( $(echo "${ZEBINARRAY[$j]} <= ${ZENITH_ANGLES[$l]}" | bc ) && $(echo "${ZEBINARRAY[$j+1]} >= ${ZENITH_ANGLES[$l]}" | bc ) ));then
                      if (( "${ZENITH_ANGLES[$l]}" != "00" && "${ZENITH_ANGLES[$l]}" != "60" && "${ZENITH_ANGLES[$l]}" != "65" )); then
                          SIGNALLIST=`ls -1 $SDIR/${ZENITH_ANGLES[$l]}deg_0.5wob_NOISE{100,130,160,200,250}.mscw.root`
                          for arg in $SIGNALLIST
                          do
                              echo "* SIGNALFILE $arg" >> $RFIL.runparameter
                          done
                      fi
                  fi
              done
          fi
      done 
      echo "#######################################################################################" >> $RFIL.runparameter
      BLIST="$ODIR/BackgroundRunlist_Ze${j}.list"
      rm -f ${BLIST}
      if [[ ! -d "${BDIR}/Ze_${j}" ]]; then
          echo "Error, directory with background files ${BDIR}/Ze_${j} not found, exiting..."
          exit 1
      fi
      ls -1 ${BDIR}/Ze_${j}/*.root > ${BLIST}
   	  for arg in $(cat $BLIST)
   	  do
         echo "* BACKGROUNDFILE $arg" >> $RFIL.runparameter
      done
         
      FSCRIPT=$LOGDIR/$ONAME"_$i""_$j"
      sed -e "s|RUNPARAM|$RFIL|"  \
          -e "s|OUTNAME|$ODIR/$ONAME_${i}_${j}|" $SUBSCRIPT.sh > $FSCRIPT.sh

      chmod u+x $FSCRIPT.sh
      echo $FSCRIPT.sh

      # run locally or on cluster
      SUBC=`$(dirname "$0")/helper_scripts/UTILITY.readSubmissionCommand.sh`
      SUBC=`eval "echo \"$SUBC\""`
      if [[ $SUBC == *"ERROR"* ]]; then
            echo $SUBC
            exit
      fi
      if [[ $SUBC == *qsub* ]]; then
         JOBID=`$SUBC $FSCRIPT.sh`
         # account for -terse changing the job number format
         if [[ $SUBC != *-terse* ]] ; then
            echo "without -terse!"      # need to match VVVVVVVV  8539483  and 3843483.1-4:2
            JOBID=$( echo "$JOBID" | grep -oP "Your job [0-9.-:]+" | awk '{ print $3 }' )
         fi
         echo "JOBID:  $JOBID"
      elif [[ $SUBC == *condor* ]]; then
        $(dirname "$0")/helper_scripts/UTILITY.condorSubmission.sh $FSCRIPT.sh $h_vmem $tmpdir_size
        condor_submit $FSCRIPT.sh.condor
      elif [[ $SUBC == *parallel* ]]; then
         echo "$FSCRIPT.sh &> $FSCRIPT.log" >> $LOGDIR/runscripts.dat
         cat $LOGDIR/runscripts.dat | $SUBC
      elif [[ "$SUBC" == *simple* ]] ; then
         "$FSCRIPT.sh" | tee "$FSCRIPT.log"
      fi
   done
done

exit
