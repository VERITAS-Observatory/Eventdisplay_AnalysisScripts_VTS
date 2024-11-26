#!/bin/bash
# Check and move anasum files for all cuts
# This script should be used in the temporary data directories for cleanup and
# move of files to their final archive destination

for C in anasum_hard2tel anasum_hard3tel anasum_moderate2tel anasum_soft2tel; do
    echo "$C"
    ./prepro_check_and_clean_files.sh "$C"
    ./prepro_move_preprocessed_files.sh "$C"
done
