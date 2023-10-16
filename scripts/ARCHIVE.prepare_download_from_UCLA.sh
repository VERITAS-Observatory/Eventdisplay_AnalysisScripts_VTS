#!/bin/bash
# Prepare a list of files to download from UCLA archive of
# preprocessed Eventdisplay data products
#
# uses bbftp for downloading
#

EDVERSION="v490"
UCLAPATH="/veritas/processed_Eventdisplay/${EDVERSION}"
ARCHIVE=$(grep VTSRAWDATA $VERITAS_EVNDISP_AUX_DIR/ParameterFiles/EVNDISP.global.runparameter | grep "*" | awk '{print $NF}')
if [ -z $ARCHIVE ]; then
    echo "Error setting archive server"
    exit
fi

if [ ! -n "$3" ] || [ "$1" = "-h" ]; then
echo "
Prepare list of files to download from UCLA archive of preprocessed Eventdisplay data products.

./ARCHIVE.prepare_download_from_UCLA.sh <runlist> <download list> <file type> [analysis type]

required parameters:

    <runlist>       simple input run list with one run number per line.

    <download list> executable script to downloaded files (generated by this script)
                    Download these files with:
                    ./<download list>

    <file type>     Eventdisplay file type.
                    Available file types:
                    - evndisp (output of evndisp)
                    - mscw (output of mscw_energy)

                    File types available for AP cleaning only:
                    - anasum_soft2tel (output of anasum, soft2tel cuts)
                    - anasum_moderate2tel (output of anasum, moderate2tel cuts)
                    - anasum_hard3tel (output of anasum, hard3tel cuts)

                    DL3 files for AP cleaning with gamma-hadron separation cuts applied:
                    - dl3_pointlike_moderate2tel (output of V2DL3, moderate2tel cuts, pointlike)
                    - dl3_pointlike_soft2tel (output of V2DL3, soft2tel cuts, pointlike)
                    - dl3_pointlike_hard3tel (output of V2DL3, hard3tel, cuts, pointlike)
                    - dl3_fullenclosure_moderate2tel (output of V2DL3, moderate2tel cuts, full enclosure)
                    - dl3_fullenclosure_soft2tel (output of V2DL3, soft2tel cuts, full enclosure)
                    - dl3_fullenclosure_hard3tel (output of V2DL3, hard3tel, cuts, full enclosure)

                    DL3 files for AP cleaning with no gamma-hadron separation cuts applied:
                    - dl3_pointlike-all-events_moderate2tel (output of V2DL3, moderate2tel cuts, pointlike)
                    - dl3_pointlike-all-events_soft2tel (output of V2DL3, soft2tel cuts, pointlike)
                    - dl3_pointlike-all-events_hard3tel (output of V2DL3, hard3tel, cuts, pointlike)
                    - dl3_fullenclosure-all-events_moderate2tel (output of V2DL3, moderate2tel cuts, full enclosure)
                    - dl3_fullenclosure-all-events_soft2tel (output of V2DL3, soft2tel cuts, full enclosure)
                    - dl3_fullenclosure-all-events_hard3tel (output of V2DL3, hard3tel, cuts, full enclosure)

optional parameters:

    [analysis type] analysis type (AP cleaning or NN cleaning; AP is default)

"
exit
fi

RLIST=$1
OLIST=$2
FTYPE=$3
[[ "$4" ]] && ATYPE=$4 || ATYPE="AP"

if [[ -e "$OLIST" ]]; then
    echo "Warning: output file list $OLIST exists; please remove"
    exit
fi

if [[ ! -e "$RLIST" ]]; then
    echo "Error: input file list $FLIST does not exist"
    exit
fi

FTYPES="evndisp mscw anasum_soft2tel anasum_moderate2tel anasum_hard3tel dl3_pointlike_moderate2tel dl3_pointlike_soft2tel dl3_pointlike_hard3tel dl3_fullenclosure_moderate2tel dl3_fullenclosure_soft2tel dl3_fullenclosure_hard3tel dl3_pointlike-all-events_moderate2tel dl3_pointlike-all-events_soft2tel dl3_pointlike-all-events_hard3tel dl3_fullenclosure-all-events_moderate2tel dl3_fullenclosure-all-events_soft2tel dl3_fullenclosure-all-events_hard3tel"
if [[ ! $(echo $FTYPES | grep -w $FTYPE) ]]; then
    echo "Error: invalid Eventdisplay file type $FTYPE"
    echo "(allowed values: $FTYPES)"
    exit
fi

ATYPES="AP NN"
if [[ ! $(echo $ATYPES | grep -w $ATYPE) ]]; then
    echo "Error: invalid analysis type $ATYPE (allowed values: $ATYPES)"
    exit
fi

echo "Preparing list of files to be downloaded from UCLA."
echo "   input run list: $RLIST ($(wc -l $RLIST | awk '{print $1}') runs)"
echo "   file type: $FTYPE"
echo "   analysis type: $ATYPE"
echo "   Eventdisplay version: $EDVERSION"
echo "   Archive server: $ARCHIVE"
echo "   Source path: $UCLAPATH"

echo -n "" > "$OLIST"
chmod u+x "$OLIST"

file_directory()
{
    TRUN="$1"
    if [[ ${TRUN} -lt 100000 ]]; then
        EDIR="${TRUN:0:1}"
    else
        EDIR="${TRUN:0:2}"
    fi
    echo "$EDIR"
}

get_file_suffix()
{
    FSUFF="root"
    if [[ $1 == "mscw" ]]; then
        FSUFF="mscw.root"
    elif [[ $1 == "anasum"* ]]; then
        FSUFF="anasum.root"
    elif [[ $1 == "dl3"* ]]; then
        FSUFF="fits.gz"
    fi
    echo "$FSUFF"
}


RUNS=$(cat $RLIST | sort -u -n)
for R in $RUNS
do
    echo "bbftp -u bbftp -V -S -m -p 12 -e \"get ${UCLAPATH}/${ATYPE}/${FTYPE}/$(file_directory $R)/$R.$(get_file_suffix $FTYPE) $R.$(get_file_suffix $FTYPE)\" ${ARCHIVE}" >> "$OLIST"
done

echo ""
echo "File list prepared."
echo "Download files with by running ./$OLIST"
