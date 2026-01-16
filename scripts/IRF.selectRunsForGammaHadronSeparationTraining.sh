#!/bin/bash
# select mscw files for BDT gamma/hadron separation training
#
# selection is based on
# - epoch
# - observation mode
# - avoidance of strong gamma-ray sources (e.g., Crab)
#
# files are linked to a new directory
#

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    echo "./IRF.selectRunsForGammaHadronSeparationTraining.sh <major epoch> <source mscw directory> <target mscw directory> <TMVA run parameter file (full path)> [verbose: 0|1]"
     echo
     echo "files are sorted in epochs, observations mode, zenith angle bins defined in TMVA run parameter file"
     echo "this script has several hardwired parameters"
     echo "verbose: 0=quiet (default), 1=show all processing details"
     exit
fi

MEPOCH="${1}"
TARGETDIR="${3}"
RUNPAR="${4}"
VERBOSE="${5:-0}"  # Default to quiet mode

# Observing mode
OBSMODE="observing"
# Multiplicity
MULT="1234"
# Skip runs shorter than this time (s)
# (require a 10 min run)
MINOBSTIME=600
# Sources to avoid
BRIGHTSOURCES=( Crab Mrk421 )

echo "Reference values: ${MEPOCH} ${OBSMODE}"
echo "Multiplicity cut: ${MULT}"
echo "Minimum observing time: ${MINOBSTIME} s"
echo "Avoiding bright sources: ${BRIGHTSOURCES[*]}"

# zenith angle bins
if [[ "${RUNPAR##*.}" == "json" ]]; then
    echo "Reading zenith bins from json file"
    ZEBIN_EDGES=$(jq -r '.zenith_bins_deg[] | "\(.Ze_min) \(.Ze_max)"' "$RUNPAR" | awk '{print $1}')
    ZEBIN_MAX=$(jq -r '.zenith_bins_deg[-1].Ze_max' "$RUNPAR")

    # Combine into a single space-separated string of unique bin edges
    ZEBINS=$(echo "$ZEBIN_EDGES" "$ZEBIN_MAX" | tr '\n' ' ' | awk '{
        # Store unique values in order
        split($0, arr);
        prev = "";
        for (i in arr) {
            if (arr[i] != prev) {
                printf "%s ", arr[i];
                prev = arr[i];
            }
        }
    }')
else
    ZEBINS=$( cat "$RUNPAR" | grep "^* ZENBINS " | sed -e 's/* ZENBINS//' | sed -e 's/ /\n/g')
fi
echo "Zenith angle definition: $ZEBINS"
declare -a ZEBINARRAY=( $ZEBINS ) #convert to array
NZEW=$((${#ZEBINARRAY[@]}-1)) #get number of bins

# Find files and store in array to handle filenames with spaces
if [[ $MEPOCH == "V4" ]]; then
    mapfile -t FLIST < <(find "${2}" -name "[3,4]*[0-9].mscw.root" | sed 's/\.root$//')
elif [[ $MEPOCH == "V5" ]]; then
    mapfile -t FLIST < <(find "${2}" -name "[4,5,6]*[0-9].mscw.root" | sed 's/\.root$//')
else
    mapfile -t FLIST < <(find "${2}" -regextype posix-extended \
      -regex '.*/(6|7|8|9|1[0-5])[0-9]*\.mscw\.root' \
      | sed 's/\.root$//')
fi

echo "Found ${#FLIST[@]} files to process"

mkdir -p "${3}"

# Pre-create zenith bin directories for efficiency
for (( j=0; j < $NZEW; j++ )); do
    mkdir -p "${TARGETDIR}/Ze_${j}"
done

linkFile()
{
    # Only create parent dir if needed (most are pre-created)
    local parent=$(dirname "$1")
    [[ -d "$parent" ]] || mkdir -p "$parent"
    if [[ ! -e "$1" ]]; then
        ln -s "$2" "$1"
    fi
}

# Process files
PROCESSED=0
SKIPPED=0
LINKED=0

for F in "${FLIST[@]}"
do
    [[ $VERBOSE -eq 1 ]] && echo "Processing file ${F}.root"
    BNAME=$(basename "${F}.root")

    # Skip if already linked
    if [[ -e "${TARGETDIR}/${BNAME}" ]]; then
        ((SKIPPED++))
        [[ $VERBOSE -eq 1 ]] && echo "  Already linked, skipping..."
        continue
    fi

    # Get run info once and parse into array for efficiency
    RUNINFO=$($EVNDISPSYS/bin/printRunParameter "${F}.root" -runinfo 2>/dev/null)
    if [[ -z "$RUNINFO" ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "  ERROR: Could not read run info"
        ((SKIPPED++))
        continue
    fi

    # Parse all fields at once into array (much more efficient than multiple awk calls)
    # Format is TAB-separated: MINOREPOCH\tTMPMEPOCH\tfield3\tTMPOBSMODE\tTMPMULT\tTMPOBSTIME\tTMPTARGET\tRUNZENITH\tfield9\tRUNWOBBLE
    IFS=$'\t' read -ra RUNINFO_ARRAY <<< "$RUNINFO"
    MINOREPOCH="${RUNINFO_ARRAY[0]:-}"
    TMPMEPOCH="${RUNINFO_ARRAY[1]:-}"
    TMPOBSMODE="${RUNINFO_ARRAY[3]:-}"
    TMPMULT="${RUNINFO_ARRAY[4]:-}"
    TMPOBSTIME="${RUNINFO_ARRAY[5]:-}"
    TMPTARGET="${RUNINFO_ARRAY[6]:-}"  # Target name (may contain spaces)
    RUNZENITH="${RUNINFO_ARRAY[7]:-}"
    RUNWOBBLE="${RUNINFO_ARRAY[9]:-}"

    # Validate numeric fields to prevent bc errors
    if [[ ! "$TMPOBSTIME" =~ ^[0-9]+\.?[0-9]*$ ]] || [[ ! "$RUNZENITH" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        [[ $VERBOSE -eq 1 ]] && echo "  ERROR: Invalid numeric values (time=$TMPOBSTIME, ze=$RUNZENITH)"
        ((SKIPPED++))
        continue
    fi

    [[ $VERBOSE -eq 1 ]] && echo "  Run info: epoch=$TMPMEPOCH, mode=$TMPOBSMODE, ze=$RUNZENITH, target=$TMPTARGET"

    # Quick filters first (fail fast)
    [[ "${TMPMEPOCH}" != "${MEPOCH}" ]] && { ((SKIPPED++)); continue; }
    [[ "${TMPOBSMODE}" != "${OBSMODE}" ]] && { [[ $VERBOSE -eq 1 ]] && echo "  SKIP: obsmode ${TMPOBSMODE}"; ((SKIPPED++)); continue; }
    [[ "${TMPMULT}" != "${MULT}" ]] && { [[ $VERBOSE -eq 1 ]] && echo "  SKIP: mult ${TMPMULT}"; ((SKIPPED++)); continue; }
    [[ "${RUNWOBBLE}" == "0" ]] && { [[ $VERBOSE -eq 1 ]] && echo "  SKIP: wobble 0"; ((SKIPPED++)); continue; }

    # Numeric comparison for observation time (integer comparison)
    if (( TMPOBSTIME < MINOBSTIME )); then
        [[ $VERBOSE -eq 1 ]] && echo "  SKIP: obstime ${TMPOBSTIME} < ${MINOBSTIME}"
        ((SKIPPED++))
        continue
    fi

    # Check bright sources
    SKIP_SOURCE=0
    for BSRC in "${BRIGHTSOURCES[@]}"; do
        if [[ "${TMPTARGET}" == "${BSRC}" ]]; then
            SKIP_SOURCE=1
            [[ $VERBOSE -eq 1 ]] && echo "  SKIP: bright source ${TMPTARGET}"
            break
        fi
    done
    [[ $SKIP_SOURCE -eq 1 ]] && { ((SKIPPED++)); continue; }

    # Find zenith bin using numeric comparison (bc for float comparison)
    ZEBIN=0
    for (( j=0; j < $NZEW; j++ )); do
        if (( $(echo "${RUNZENITH} > ${ZEBINARRAY[$j]}" | bc -l) )) && \
           (( $(echo "${RUNZENITH} < ${ZEBINARRAY[$j+1]}" | bc -l) )); then
            ZEBIN=$j
            break
        fi
    done

    [[ $VERBOSE -eq 1 ]] && echo "  ACCEPT: ${TMPTARGET} Ze=${RUNZENITH} (bin ${ZEBIN}), t=${TMPOBSTIME}s"

    # Create minor epoch directory if needed
    [[ -d "${TARGETDIR}/${MINOREPOCH}" ]] || mkdir -p "${TARGETDIR}/${MINOREPOCH}"
    [[ -d "${TARGETDIR}/${MINOREPOCH}/Ze_${ZEBIN}" ]] || mkdir -p "${TARGETDIR}/${MINOREPOCH}/Ze_${ZEBIN}"

    ((PROCESSED++))
    BNAME=$(basename "${F}.root")

    ## linking
    linkFile "${TARGETDIR}/${BNAME}" "${F}.root"
    linkFile "${TARGETDIR}/Ze_${ZEBIN}/${BNAME}" "${F}.root"
    linkFile "${TARGETDIR}/${MINOREPOCH}/${BNAME}" "${F}.root"
    linkFile "${TARGETDIR}/${MINOREPOCH}/Ze_${ZEBIN}/${BNAME}" "${F}.root"
    ((LINKED++))
done

# Summary
echo
echo "============================================"
echo "Processing complete:"
echo "  Total files found: ${#FLIST[@]}"
echo "  Files processed:   $PROCESSED"
echo "  Files linked:      $LINKED"
echo "  Files skipped:     $SKIPPED"
echo "============================================"
