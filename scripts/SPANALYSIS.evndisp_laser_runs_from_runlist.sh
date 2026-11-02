#!/bin/bash

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
# begin help message
echo "
EVNDISP special-purpose analysis: laser/flasher calibration for simple run list

Reads simple run list, gets the corresponding laser run numbers and calculates
gains/toffsets for those runs (if the gain files don't exist yet)

SPANALYSIS.evndisp_laser_runs_from_runlist.sh <runlist> [teltoana]

required parameters:

    <runlist>           simple run list with one run number per line

optional parameters:

    [teltoana]          use 1 T1 only, 13 for T1 and T3 only, etc.
                        (default telescope combination is 1234)

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$(dirname "$0")/helper_scripts/UTILITY.script_init.sh" || exit 1

# Parse command line arguments
RLIST=$1
[[ "$2" ]] && TELTOANA=$2 || TELTOANA="1234"
TELTOANA=$(echo "$TELTOANA" | fold -w1)

# locations of vbf files and laser/flasher calibration files
DDIR="$VERITAS_DATA_DIR/data/"
CALIBDIR="$VERITAS_EVNDISP_AUX_DIR/Calibration/"

# Read runlist
if [[ ! -f "$RLIST" ]]; then
    echo "Error, runlist $RLIST not found, exiting..."
    exit 1
fi
RUNNUMS=$(cat "$RLIST")

for DATA_RUN in $RUNNUMS; do
    for i in $TELTOANA; do
        LASER_RUN=$("$EVNDISPSYS"/bin/VTS.getLaserRunFromDB "$i" "$DATA_RUN") || exit 1
        [[ $LASER_RUN =~ ^[0-9]+$ ]] || exit 1
        echo "Checking telescope $i, laser run $LASER_RUN, data run $DATA_RUN:"
        echo "$CALIBDIR/Tel_$i/$LASER_RUN.gain.root"

        if [[ ! -f "$CALIBDIR/Tel_$i/$LASER_RUN.gain.root" ]]; then
            echo "Processing gains from laser/flash run $LASER_RUN, telescope $i"
            RUNFILE=$(find -L "$DDIR" -name "$LASER_RUN.cvbf")
            if [[ -f $RUNFILE ]]; then
                "$(dirname "$0")/SPANALYSIS.evndisp_laser_run.sh" "$LASER_RUN" "$i" || exit 1
            else
                echo "Missing laser/flasher file $RUNFILE, please download it"
            fi
        else
            echo "...gain and toffset files already on disk"
        fi
    done
done

exit
