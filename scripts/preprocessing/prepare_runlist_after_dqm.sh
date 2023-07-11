#!/bin/bash
# Prepare run lists and time cuts using the 
# DQM information.
#
# uses DBText files and removes all runs with
#  - flagged as not "science"
#  - flagged as "do not use"
#  - usable duration less than 5 min
#
#  Output of this scripts are:
# - run lists per epoch
# - time masks per epoch

if [ ! -n "$4" ] || [ "$1" = "-h" ]; then
echo "
Prepare run lists for different epochs from files in a given directory.

./prepare_runlist_after_dqm.sh <directory> <file type> <suffix> <list of broken runs>

file type: e.g., "8*.root"

"
exit
fi

FILEDIR="${1}"
FILETYPE="${2}"
FILESUFFIX="${3}"

# DQM files are read this directory
DBTEXTDIRECTORY="$VERITAS_DATA_DIR/DBTEXT"

# List of broken runs
# (not caught with the logic below)
BROKENRUNS=$(cut -d ' ' -f 1 ${4})

get_db_text_tar_file()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo "${DBTEXTDIRECTORY}/${SRUN}/${RRUN}.tar.gz"
}

prepare_output_files()
{
    for E in "" _V4 _V5 _V6; do
        echo -n "" > runlist${E}.dat
        echo -n "" > timemask${E}.dat
    done
    echo -n "" > runlist_V6_redHV.dat
    echo -n "" > runlist_V6_UV.dat
    echo -n "" > runlist_NULL.dat
    echo -n "" > runlist_NODQM.dat
    echo -n "" > runlist_NOTARGET.dat
}

get_epoch()
{
    E="_V6"
    if [[ $1 -lt 46642 ]]; then
        E="_V4"
    elif [[ $1 -lt 63373 ]]; then
        E="_V5"
    fi
    echo "${E}"
}

fill_run()
{
    echo "$1" >> runlist.dat
    if [[ "$2" == "moonfilter" ]]; then
        echo "$1" >> runlist$(get_epoch $1)_UV.dat
    elif [[ "$2" == "reducedhv" ]]; then
        echo "$1" >> runlist$(get_epoch $1)_redHV.dat
    else
        echo "$1" >> runlist$(get_epoch $1).dat
    fi
}

fill_timemask()
{
    TMASK_1=$(echo $2 | cut -d '/' -f 1)
    TMASK_1=$(printf "%.0f" "$TMASK_1")
    TMASK_2=$(echo $2 | cut -d '/' -f 2)
    TMASK_2=$(printf "%.0f" "$TMASK_2")
    TMASK="* $1 $TMASK_1 $((TMASK_2 - TMASK_1)) 0"
    echo "$TMASK" >> timemask.dat
    echo "$TMASK" >> timemask$(get_epoch $1).dat
}

prepare_output_files

RUNS=$(find ${FILEDIR} -name "$FILETYPE")

for RF in $RUNS
do
    R=$(basename "$RF" "$FILESUFFIX")
    # make sure this is a valid runnumber
    if [[ ${#R} -ne 5 ]] && [[ ${#R} -ne 6 ]]; then
        continue
    fi
    echo
    echo "RUN $R"
    # check if this is in the list of broken runs
    if [[ $BROKENRUNS = *"$R"* ]]; then
        echo "   RUN $R broken (BROKENCUT APPLIED)"
        continue
    fi
    DBTEXTFILE=$(get_db_text_tar_file ${R})
    # Target file
    TARGETFILE="${R}/${R}.target"
    # DQM File
    DQMFILE="${R}/${R}.rundqm"
    # RUNINFO file
    INFOFILE="${R}/${R}.runinfo"
    if [[ -e ${DBTEXTFILE} ]]; then
        if [[ -z $(tar -tzf ${DBTEXTFILE} | grep "${DQMFILE}") ]]; then
            echo "   RUN $R no DQM file ${DQMFILE} found (NODQMFILE CUT APPLIED)"
            echo ${R} >> runlist_NODQM.dat
            continue
        fi
        # DQM string
        DQMSTRING=$(tar -axf ${DBTEXTFILE} ${DQMFILE} -O)
        echo $DQMSTRING
        # data category
        RCAT=$(echo "${DQMSTRING}" | cut -d '|' -f 2 ${RDQM} | grep -v data_category)
        # (especially early runs do not have a science category)
        if [[ ${RCAT} != "science" ]] \
            && [[ ${RCAT} != "reducedhv" ]] \
            && [[ ${RCAT} != "moonfilter" ]] \
            && [[ ${RCAT} != "NULL" ]]; then
            echo "   RUN $R $RCAT (CATEGORY CUT APPLIED)"
            continue
        fi
        # DQM status
        RSTATUS=$(echo "${DQMSTRING}" | cut -d '|' -f 3 ${RDQM} | grep -v status)
        if [[ ${RSTATUS} == "do_not_use" ]] || [[ ${RSTATUS} == "NULL" ]]; then
            # early V4 runs without DQM
            if [[ ${RSTATUS} == "do_not_use" ]] || [[ $R -gt 46642 ]]; then
                echo "   RUN $R $RSTATUS (STATUS CUT APPLIED)"
                if [[ ${RSTATUS} == "NULL" ]] && [[ ${RCAT} != "NULL" ]]; then
                    echo $R >> runlist_NULL.dat
                fi
                continue
            fi
        fi
        # usable duration
        RUSABLE=$(echo "${DQMSTRING}" | cut -d '|' -f 6 ${RDQM} | grep -v usable_duration)
        if [[ $RUSABLE != "NULL" ]]; then
            RTUSABLE=$(echo $RUSABLE | awk 'NR==1 {split($1, arr, "[:]"); print arr[2]}')
            if [[ $((10#$RTUSABLE)) -lt 5 ]]; then
                echo "   RUN $R $RSTATUS $RTUSABLE (TIME CUT APPLIED; $RUSABLE)"
                continue
            fi
        # V4 runs partly withtout DQM
        elif [[ $R -gt 46642 ]]; then
            echo "   RUN $R $RSTATUS $RUSABLE (NO TIME CUTS DEFINED)"
            continue
        fi
        # data duration frum run info
        INFOSTRING=$(tar -axf ${DBTEXTFILE} ${INFOFILE} -O)
        echo $INFOSTRING
        RDATAT1=$(echo "${INFOSTRING}" | cut -d '|' -f 7 ${RDQM} | grep -v data_start_time)
        RDATAT2=$(echo "${INFOSTRING}" | cut -d '|' -f 8 ${RDQM} | grep -v data_end_time)
        echo "  RUN $R $RDATAT1 $RDATAT2"
        RDATAT1=$(date -d "$RDATAT1" +%s)
        RDATAT2=$(date -d "$RDATAT2" +%s)
        DATADURATION=$((RDATAT2 - RDATAT1))
        echo "  RUN $R DURATION $DATADURATION"
        if [ $DATADURATION -lt  120 ]; then
            echo "   RUN $R short (<2 min) duration $DATADURATION s (DATADURATION CUT APPLIED)"
            continue
        fi
        # time mask
        RCUTMASK=$(echo "${DQMSTRING}" | cut -d '|' -f 7 ${RDQM} | grep -v time_cut_mask)
        if [[ $RCUTMASK != "NULL" ]]; then
            IFS=','
            for TCUT in $RCUTMASK
            do
                fill_timemask $R $TCUT
            done
        fi
        if [[ -z $(tar -tzf ${DBTEXTFILE} | grep "${TARGETFILE}") ]]; then
            echo "   RUN $R no target file ${TARGETFILE} found (NOTARGETFILE CUT APPLIED)"
            echo ${R} >> runlist_NOTARGETFILE.dat
            continue
        fi
        # TARGET string
        TARGETSTRING=$(tar -axf ${DBTEXTFILE} ${TARGETFILE} -O)
        echo $TARGETSTRING
        # skip targets DARK...
        RTARGET=$(echo "${TARGETSTRING}" | cut -d '|' -f 1 | grep -v source_id)
        echo "   RUN $R  $RTARGET"
        if [[ $RTARGET == "DARK_"* ]]; then
            echo "   RUN $R DARK_ target (DARKTARGET CUT APPLIED)"
            continue
        fi
        # skip laser and flasher runs
        if [[ $RTARGET == "laser" ]] || [[ $RTARGET == "flasher" ]]; then
            echo "   RUN $R $TARGET target (FLASHER CUT APPLIED)"
            continue
        fi
    else
        RSTATUS="NODQMFILE"
        RCUTMASK="NULL"
    fi
    echo "   $R $RSTATUS $RUSABLE $RCUTMASK"
    fill_run $R $RCAT
done
