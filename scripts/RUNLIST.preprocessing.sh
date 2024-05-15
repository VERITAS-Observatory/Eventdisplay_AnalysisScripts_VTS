#!/bin/bash
# Generates a simple run list (one run per line) with quality cuts

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
# begin help message
echo "
EVNDISP runlist script: generate a simple run list (one run per line)
with loose quality cuts used for preprocessing.

RUNLIST.preprocessing.sh [start date] [end date]

    [start date]            select all runs on or after this date
                            (default: 2011-01-01, format = YYYY-MM-DD)

    [end date]              select all runs on or before this date
                            (default: none, format = YYYY-MM-DD)

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash "$( cd "$( dirname "$0" )" && pwd )/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
[[ "$1" ]] && START_DATE=$1" 00:00:00" || START_DATE="2011-01-01 00:00:00"
[[ "$2" ]] && END_DATE_STR="and db_end_time <= '$2 00:00:00'"
MIN_DURATION=2
#  Use '%' for all runs.
MODE="%"
# science calibration, engineering, moonfilter, reducedhv, special (but see call below)
DQMCATEGORY="science"

# three telescope configuration
TEL_MASKS="('15', '7', '11', '13', '14')"
TEL_CUT_MASKS="('0', '8', '4', '2', '1')"

# Get VERITAS database URL from EVNDISP.global.runparameter file
MYSQLDB=`grep '^\*[ \t]*DBSERVER[ \t]*mysql://' $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/EVNDISP.global.runparameter | egrep -o '[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}'`
if [ ! -n "$MYSQLDB" ]; then
    echo "* DBSERVER param not found in \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/EVNDISP.global.runparameter!"
    exit 1
fi

# Get run numbers from database using MySQL query
MYSQL="mysql -u readonly -h $MYSQLDB -A"
RUNINFOARRAY=()
while read -r RUNID; do
	if [[ "$RUNID" =~ ^[0-9]+$ ]]; then
		RUNINFOARRAY+=("$RUNID")
	fi
done < <($MYSQL -e " select run_id from VERITAS.tblRun_Info where run_type LIKE \"$MODE\" and observing_mode = 'wobble' and duration >= '00:${MIN_DURATION}:00' and db_start_time >= '$START_DATE' $END_DATE_STR and config_mask in $TEL_MASKS ;")

# check if VERITAS.tblRun_Info had 0 runs for us
if (( ${#RUNINFOARRAY[@]} <= 0 )) ; then
	# if so, error out and tell the user why
	echo "Error, no runs fit current conditions. Exiting..." 2>&1
	exit 1
fi

# Convert RUNINFOARRAY to a comma-separated tuple
RUN_IDS=$(IFS=, ; echo "(${RUNINFOARRAY[*]})")

# Do some final quality checks using the VOFFLINE.tblRun_Analysis_Comments table
FINALARRAY=()
while read -r RUNID; do
	if [[ "$RUNID" =~ ^[0-9]+$ ]] ; then
		FINALARRAY+=("$RUNID")
		echo "$RUNID"
	fi
done < <($MYSQL -e "select run_id from VOFFLINE.tblRun_Analysis_Comments where status != 'do_not_use' and (tel_cut_mask is NULL or tel_cut_mask in $TEL_CUT_MASKS) and ( data_category like \"science\" or data_category like \"reducedhv\" or data_category like \"moonfilter\" or ( \"$DQMCATEGORY\" = \"%\" and data_category is null )  ) and usable_duration >= '00:${MIN_DURATION}:00' and run_id in ${RUN_IDS[@]}")

exit
