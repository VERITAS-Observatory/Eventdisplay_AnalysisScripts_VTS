#!/bin/bash
# Check and move v2dl3 files for all cuts

for C in v2dl3_hard2tel v2dl3_hard3tel v2dl3_moderate2tel v2dl3_soft2tel; do
    for A in point-like  full-enclosure-all-events  full-enclosure  point-like-all-events; do
        D="$C/$A"
        echo $D
        ./prepro_check_and_clean_files.sh "$D"
        ./prepro_move_v2dl3_files.sh "$D"
    done
done
