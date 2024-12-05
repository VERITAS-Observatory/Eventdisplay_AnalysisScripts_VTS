#!/bin/bash
# Check and move v2dl3 files for all cuts

ANATYPE="${VERITAS_ANALYSIS_TYPE:0:2}"
CUTLIST="v2dl3_hard2tel v2dl3_hard3tel v2dl3_moderate2tel v2dl3_soft2tel"
if [[ $ANATYPE == "NN" ]]; then
    CUTLIST="v2dl3_supersoftNN2tel"
fi

for C in $CUTLIST; do
    for A in point-like  full-enclosure-all-events  full-enclosure  point-like-all-events; do
        D="$C/$A"
        DDIR=${A/full-enclosure/fullenclosure}_${C/v2dl3_/}
        DDIR=dl3_${DDIR/point-like/pointlike}
        echo "Source directory: $D Targetdirectory: $DDIR"
#        ./prepro_check_and_clean_files.sh "$D"
        $(dirname "$(realpath "$0")")/prepro_move_v2dl3_files.sh "$D" "$DDIR"
    done
done
