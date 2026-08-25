#!/bin/bash
if [ $# -lt 1 ]; then
echo "
./prepro_check_and_clean_files.sh <analysis type>

    Check log files for a given analysis type for errors and segmentation fault.
    Move error files into a error directory.
    Recover files from error directory for files successfully processed.

    grep -i error ./mscw/*.log | grep -v BDTDispError | grep -v "BDT disp" | grep -v weighting
"
    exit
fi

FTYPE="$1"
echo "Searching for errors for data type $FTYPE"

# simplified search for mscw
if [[ $FTYPE == "mscw" ]]; then
    grep -i error ./mscw/*.log | grep -Ev 'BDTDispError|BDT disp|weighting'
    echo "Finalized error search for mscw"
    exit
fi

# find all files with errors in the log file
move_list()
{
    mkdir -p "${FTYPE}"/"${1}"
    for F in ${2}; do
        mv -f "${FTYPE}/$(basename "$F" .log)."* "${FTYPE}/${1}/"
    done
}

# for xgb products: require the eventdisplay-ml completion message
if [[ $FTYPE == "xgb" ]]; then
    xgb_bad_logs=""
    shopt -s nullglob
    for F in "$FTYPE"/*.log; do
        if ! grep -qF "INFO:eventdisplay_ml.models:Total processed events written" "$F"; then
            xgb_bad_logs+="$F "$'\n'
        fi
    done
    shopt -u nullglob

    if [[ -n $xgb_bad_logs ]]; then
        file_count=$(echo "$xgb_bad_logs" | wc -w)
        echo "FOUND $file_count xgb log files without the eventdisplay-ml completion message"
        move_list error "$xgb_bad_logs"
    fi
fi

if [[ $FTYPE == "v2dl3" ]]; then
    echo "Checking v2dl3 logs below v2dl3_* (progress every 1,000 logs)"

    # Scan each log once. Perl handles the file loop, text matching, progress
    # reporting, and file moves in one process; the previous implementation
    # started several grep processes and traversed the complete tree three times.
    find . -mindepth 3 -maxdepth 3 -type f \
        -path './v2dl3_*/*/*.log' -print0 |
    perl -0ne '
        use strict;
        use warnings;
        use File::Basename qw(basename dirname);
        use File::Path qw(make_path);
        use IO::Handle;

        our ($completion, $progress_interval, $scanned, $missing_completion,
             $with_errors, $with_segmentation, $moved, $cleaned_logs,
             $cleaned_products);
        our %clean_stems;

        BEGIN {
            STDERR->autoflush(1);
            $completion = "INFO:v2dl3: FITS output written to";
            $progress_interval = 1000;
            $scanned = 0;
            $missing_completion = 0;
            $with_errors = 0;
            $with_segmentation = 0;
            $moved = 0;
            $cleaned_logs = 0;
            $cleaned_products = 0;
        }

        sub sibling_products {
            my ($file) = @_;
            my $dir = dirname($file);
            my $stem = basename($file);
            $stem =~ s/\.log\z//;
            return ($dir, $stem);
        }

        sub move_to_error {
            my ($file) = @_;
            my ($dir, $stem) = sibling_products($file);
            my $error_dir = "$dir/error";
            make_path($error_dir) unless -d $error_dir;
            opendir(my $dh, $dir) or die "Cannot read $dir: $!";
            my @products = grep { /^\Q$stem\E\./ } readdir($dh);
            closedir($dh);
            for my $product (@products) {
                rename("$dir/$product", "$error_dir/$product")
                    or die "Cannot move $dir/$product: $!";
            }
        }

        my $file = $_;
        chomp($file);
        my ($has_completion, $has_error, $has_segmentation) = (0, 0, 0);
        open(my $fh, "<", $file) or die "Cannot read $file: $!";
        while (my $line = <$fh>) {
            $has_completion = 1 if index($line, $completion) >= 0;
            $has_error = 1 if lc($line) =~ /error/;
            $has_segmentation = 1 if $line =~ /segmentation/;
        }
        close($fh) or die "Cannot close $file: $!";

        $scanned++;
        $missing_completion++ unless $has_completion;
        $with_errors++ if $has_error;
        $with_segmentation++ if $has_segmentation;

        if (!$has_completion || $has_error || $has_segmentation) {
            move_to_error($file);
            $moved++;
        } else {
            my ($dir, $stem) = sibling_products($file);
            $clean_stems{$dir}{$stem} = 1;
            $cleaned_logs++;
        }

        if ($scanned % $progress_interval == 0) {
            printf STDERR "v2dl3 progress: %d logs checked\n", $scanned;
        }

        END {
            for my $dir (keys %clean_stems) {
                my $error_dir = "$dir/error";
                next unless -d $error_dir;
                opendir(my $dh, $error_dir) or die "Cannot read $error_dir: $!";
                for my $product (readdir($dh)) {
                    my ($stem) = $product =~ /\A(.+?)\./;
                    next unless $stem && $clean_stems{$dir}{$stem};
                    unlink "$error_dir/$product"
                        or die "Cannot remove $error_dir/$product: $!";
                    $cleaned_products++;
                }
                closedir($dh);
            }
            printf "v2dl3 check complete: %d logs checked, %d moved to error, %d stale error products cleaned\n", $scanned, $moved, $cleaned_products;
            printf "FOUND %d v2dl3 log files without the FITS output completion message\n", $missing_completion if $missing_completion;
            printf "FOUND %d v2dl3 files with errors\n", $with_errors if $with_errors;
            printf "FOUND %d v2dl3 files with segmentation faults\n", $with_segmentation if $with_segmentation;
        }
    '
    v2dl3_status=("${PIPESTATUS[@]}")
    if [[ ${v2dl3_status[0]} -ne 0 || ${v2dl3_status[1]} -ne 0 ]]; then
        echo "v2dl3 log check failed" >&2
        exit 1
    fi
    exit
fi

# for anasum products: require VERITAS_ANALYSIS_TYPE in the last log line
if [[ $FTYPE == anasum* ]]; then
    anasum_bad_logs=""
    shopt -s nullglob
    for F in "$FTYPE"/*.log; do
        if ! tail -n 1 "$F" | grep -q "VERITAS_ANALYSIS_TYPE"; then
            anasum_bad_logs+="$F "$'\n'
        fi
    done
    shopt -u nullglob

    if [[ -n $anasum_bad_logs ]]; then
        file_count=$(echo "$anasum_bad_logs" | wc -w)
        echo "FOUND $file_count anasum log files without VERITAS_ANALYSIS_TYPE in the last line"
        move_list error "$anasum_bad_logs"
    fi
fi

# find all runs with errors and move them
FLIST=$(grep -irl "error" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with errors"
    fi
    move_list error "$FLIST"
fi
# find all runs with segmentation faults
FLIST=$(grep -rl "segmentation" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files with segmentation faults"
    fi
    move_list error "$FLIST"
fi
# find all runs without errors and remove them from error directory
FLIST=$(grep -iL "error" "$FTYPE"/*.log)
if [[ -n $FLIST ]]; then
    file_count=$(echo "$FLIST" | wc -w)
    if [[ ! -z $file_count ]]; then
        echo "FOUND $file_count files without errors - cleaning error directory"
        for F in $FLIST; do
            rm -f "${FTYPE}/error/$(basename "$F" .log)."*
        done
    fi
fi

echo "Aux data (and NOTFOUND)"
NAUX=$(find "$FTYPE" -maxdepth 1 -name "*.NOTFOUND" 2>/dev/null | wc -l)
if [[ $NAUX -gt 0 ]]; then
    mkdir -p "$FTYPE"/aux
    mv -f "$FTYPE"/*.NOTFOUND "$FTYPE"/aux/
fi
echo "Remove list file (*.list, *.runlist)"
rm -f "$FTYPE"/*.list
rm -f "$FTYPE"/*.runlist
