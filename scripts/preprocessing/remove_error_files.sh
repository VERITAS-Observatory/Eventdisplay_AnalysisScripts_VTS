# Read a run list and check for errors
# in log files
# remove files with errors.


FF=$(cat do_no_use.log)

get_suffix()
{
    RRUN=${1}
    if [[ ${RRUN} -lt 100000 ]]; then
        SRUN=${RRUN:0:1}
    else
        SRUN=${RRUN:0:2}
    fi
    echo ${SRUN}
}

for F in $FF
do
    DDIR="$VERITAS_DATA_DIR/processed_data_v490/AP/evndisp/$(get_suffix $F)/"
    if [[ -e $DDIR/$F.log ]]; then
        EE=$(grep -i error $DDIR/$F.log)
        if [[ -n ${EE} ]]; then
            ls $DDIR/$F.log
        fi
    fi
done
