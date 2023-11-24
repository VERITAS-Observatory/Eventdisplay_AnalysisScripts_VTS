#!/bin/bash
# Run anasum analysis applying pre-selection cuts to be used
# for BDT cut optimisation

if [ $# -ne 2 ]; then
echo "
    ./IRF.anasumforTMVAOptimisation.sh <BDT training mscw directory> <output directory>

    Run anasum with pre-selection cuts to be used for MVA cut optimisation.
   
    This script has several hardwired parameters
"    
exit
fi

IDIR="${1}"
ODIR="${2}"
ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
RUNPARAMETER="$EVNDISPSYS/../EventDisplay_Release_v490/preprocessing/parameter_files/anasum.runparameter.dat"

if [[ ${ANATYPE} == "AP" ]]; then
    CUTLIST="NTel2-Moderate NTel2-Soft NTel3-Hard"
else
    CUTLIST="NTel2-SuperSoft"
fi

for CUT in ${CUTLIST}
do
    echo "Preparing ${CUT} to ${ODIR}/${CUT}"
    # Output directory
    mkdir -p ${ODIR}/${CUT}

    # anasum run list
    RUNLIST="${ODIR}/${CUT}/anasum.runlist"
    rm -f ${RUNLIST}
    find ${IDIR}/  -maxdepth 1 -name "[0-9]*.mscw.root" -exec basename {} .mscw.root \; > ${RUNLIST}
    sort -n -o ${RUNLIST} ${RUNLIST}
    echo "Found $(wc -l ${RUNLIST}) runs"

    ACUT="${CUT/-/}Pre"
    echo "Submit anasum for ${ACUT} using ${RUNPARAMETER}"

    ./ANALYSIS.anasum_parallel_from_runlist.sh \
        ${RUNLIST} \
        ${ODIR}/${CUT} \
        ${ACUT} \
        IGNOREIRF \
        ${RUNPARAMETER}
done
