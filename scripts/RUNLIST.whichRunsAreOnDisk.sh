#!/bin/bash
# From a run list, print the list of runs that are on disk.

NOTFLAG=false
PRINTPATH=false
DELETEFLAG=false
CHECKFLAG=false
INPUT_FROM_STDIN=false

print_help()
{
    echo
    echo "Print the run numbers that ARE stored on disk:"
    echo "  $ $(basename "$0") <file of runs>"
    echo
    echo "Print the full paths of runs that ARE stored on disk:"
    echo "  $ $(basename "$0") -p <file of runs>"
    echo
    echo "Print the run numbers that are NOT stored on disk:"
    echo "  $ $(basename "$0") -n <file of runs>"
    echo
    echo "Delete the .cvbf files for runs that ARE stored on disk:"
    echo "  $ $(basename "$0") -d <file of runs>"
    echo "  This first prints every .cvbf path that would be deleted and then asks"
    echo "  for confirmation. No files are deleted unless the answer is 'y' or 'yes'."
    echo
    echo "The run list can also be supplied on standard input, for example:"
    echo "  $ cat <file of runs> | $(basename "$0")"
    echo "  $ cat <file of runs> | $(basename "$0") -n"
    echo "  $ cat <file of runs> | $(basename "$0") -d"
    echo
}

while getopts ":npcdh" OPTION; do
    case "$OPTION" in
        n) NOTFLAG=true ;;
        p) PRINTPATH=true ;;
        c) CHECKFLAG=true ;;
        d) DELETEFLAG=true ;;
        h)
            print_help
            exit 0
            ;;
        :|\?)
            echo "Error: $(basename "$0") doesn't understand option '-$OPTARG'." >&2
            print_help >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

if (( $# > 1 )); then
    echo "Error: expected at most one run-list file." >&2
    print_help >&2
    exit 1
fi
if { $NOTFLAG && $PRINTPATH; } || { $NOTFLAG && $DELETEFLAG; } || { $PRINTPATH && $DELETEFLAG; }; then
    echo "Error: options -n, -p, and -d cannot be combined." >&2
    exit 1
fi

if (( $# == 1 )); then
    RUNFILE=$1
    if [ ! -f "$RUNFILE" ]; then
        echo "File '$RUNFILE' could not be found, sorry." >&2
        exit 1
    fi
    RUNLISTTMP=$(<"$RUNFILE")
elif [ ! -t 0 ]; then
    INPUT_FROM_STDIN=true
    RUNLISTTMP=$(cat)
else
    print_help
    exit 1
fi

RUNLIST=$(grep -E '^[0-9]+$' <<< "$RUNLISTTMP")
if [ -z "$RUNLIST" ] ; then
    echo "Error: input file/pipe contains no runs, exiting..." >&2
    exit 1
fi
#echo "RUNLIST:$RUNLIST"
#echo "Files not on disk:"

# find the veritas db url
MYSQLDB=$(grep '^\*[ \t]*DBSERVER[ \t]*mysql://' "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/EVNDISP.global.runparameter | grep -E -o '[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}\.[[:alpha:]]{1,20}')
if [ -z "$MYSQLDB" ] ; then
    echo "* DBSERVER param not found in \$VERITAS_EVNDISP_AUX_DIR/ParameterFiles/EVNDISP.global.runparameter!" >&2
    exit 1
fi

# mysql login info
MYSQL=(mysql -u readonly -h "$MYSQLDB" -A)

# generate list of runs to ask for ( run_id = RUNID[1] OR run_id = RUNID[2] etc)
COUNT=0
SUB=""
for ARUN in $RUNLIST ; do
	if (( ARUN > 0 )); then
		if [[ "$COUNT" -eq 0 ]] ; then
			SUB="run_id = $ARUN"
		else
			SUB="$SUB OR run_id = $ARUN"
		fi
		COUNT=$((COUNT+1))
	fi
done
#echo "SUB:"
#echo "$SUB"

# Search through mysql result rows, where each row's elements are assigned to
# RUNID and RUNDATE. In deletion mode, collect paths so confirmation happens
# only after the complete list has been printed.
FILES_TO_DELETE=()
while read -r RUNID RUNDATE ; do
	if [[ "$RUNID" =~ ^[0-9]+$ ]] ; then

		# decode the date tag
		read -r YY MM DD _ _ _ <<< "${RUNDATE//[-:]/ }"
		#echo "  YEARMONTHDAY:$YY$MM$DD"

		# generate the filename
		TARGFILE="$VERITAS_DATA_DIR/data/d$YY$MM$DD/$RUNID.cvbf"

		# test to see if the file exists
		#echo "  Does file exist: $TARGFILE"
		if [ -e "$TARGFILE" ] ; then # file exists
			if ! $NOTFLAG ; then # $NOTFLAG is false, and we should print the runnumber
                if $DELETEFLAG ; then
                    echo "$TARGFILE"
                    FILES_TO_DELETE+=("$TARGFILE")
                elif $PRINTPATH ; then
                    echo "$TARGFILE"
                else
                    echo "$RUNID"
                fi
			fi
		else # file does not exist
			if $NOTFLAG ; then # $NOTFLAG is true, and we should print the runnumber
				echo "$RUNID"
            elif $CHECKFLAG ; then
                echo "file not found - date: $YY$MM$DD"
            elif ! $DELETEFLAG && ! $PRINTPATH ; then
                RAWDATASERVER=$(grep "\* VTSRAWDATA" "$VERITAS_EVNDISP_AUX_DIR"/ParameterFiles/EVNDISP.global.runparameter | awk '{print $3}')
                echo "[[ ! -f \"$VERITAS_DATA_DIR/data/d$YY$MM$DD/$RUNID.cvbf\" ]] && bbftp -V -S -p 12 -u bbftp -e \"mget /veritas/data/d$YY$MM$DD/$RUNID.cvbf $VERITAS_DATA_DIR/data/d$YY$MM$DD/\" $RAWDATASERVER || echo 'File already exists, skipping download.'"
			fi
		fi
	fi
# This is where the MYSQL command is executed, with the list of requested runs
# You have to do it this way, because using a pipe | calls the command in a
# subshell, and that prevents variables from being saved within the 'while' loop
# http://stackoverflow.com/questions/14585045/is-it-possible-to-avoid-pipes-when-reading-from-mysql-in-bash
done < <("${MYSQL[@]}" -e "USE VERITAS ; SELECT run_id, data_start_time FROM tblRun_Info WHERE $SUB")

if $DELETEFLAG; then
    if (( ${#FILES_TO_DELETE[@]} == 0 )); then
        echo "No .cvbf files from the run list are on disk."
        exit 0
    fi

    if $INPUT_FROM_STDIN; then
        if [ ! -r /dev/tty ]; then
            echo "Deletion cancelled: a terminal is required for confirmation." >&2
            exit 1
        fi
        read -r -p "Delete these ${#FILES_TO_DELETE[@]} file(s)? [y/N] " CONFIRMATION < /dev/tty
    else
        read -r -p "Delete these ${#FILES_TO_DELETE[@]} file(s)? [y/N] " CONFIRMATION
    fi

    if [[ ! "$CONFIRMATION" =~ ^([yY]|[yY][eE][sS])$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi

    DELETE_FAILED=false
    for TARGFILE in "${FILES_TO_DELETE[@]}"; do
        if ! rm -- "$TARGFILE"; then
            DELETE_FAILED=true
        fi
    done
    if $DELETE_FAILED; then
        echo "Error: one or more files could not be deleted." >&2
        exit 1
    fi
    echo "Deleted ${#FILES_TO_DELETE[@]} file(s)."
fi

exit 0
