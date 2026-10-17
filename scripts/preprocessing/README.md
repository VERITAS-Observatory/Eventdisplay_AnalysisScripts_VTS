# Scripts for VERITAS Archival preprocessing

Preprocessing scripts for VERITAS data at DESY.

## Run list preparation

Requires DBTEXT files for all runs. Create a DQM-filtered run list:

```bash
./prepare_runlist_after_dqm.sh $VERITAS_DATA_DIR/DBTEXT/ "*.tar.gz" .tar.gz \
        $EVNDISPSYS/../EventDisplay_Release_v490/preprocessing/runlists_good_observation_runs/runs_not_processed.dat > dqm.log
```

Find runs marked `do_not_use` with:

```bash
grep "do_not_use (STATUS CUT APPLIED)" dqm.log
```

## Data product packing

Pack a data type:

```bash
./pack_data_files.sh mscw tmp_packing/22s.list 22s
```

Upload a package to the DESY cloud:

```bash
curl -u username -T 10.tar.gz \
    "https://syncandshare.desy.de/remote.php/dav/files/username/Shared/VTS/22s/10.tar.gz"
```

## Check and move preprocessed files

### Check Laser/Flasher runs against DBTEXT

Compare laser runs in evndisp logs with the corresponding DBTEXT `.laserrun`
files:

```bash
./check_laser_run_consistency.sh \
    "$VERITAS_DATA_DIR/shared/processed_data_v490.7/AP/evndisp" \
    "$VERITAS_DATA_DIR/shared/DBTEXT" \
    laser_run_discrepancies.tsv
```

The tab-separated report has one row per telescope discrepancy. A nonzero exit
status indicates a discrepancy or missing/unreadable input. The
`excluded_telescopes` bits 0–3 represent T1–T4.

### Move files for all data products from list of runs

Move Eventdisplay products from all stages to `runs_with_issues`:

```bash
./archive_error_files.sh <run list>
```

### Check DL3 FITS and log counts

```bash
./check_dl3_number_of_files_per_cut.sh <directory>
```

### Check preprocessing completeness

Compare reference `<run>.root` files with evndisp, mscw, anasum, and DL3
products. The reference directory defaults to `<production-directory>/evndisp`.
The checker supports productions with more than 50,000 files:

```bash
./check_preprocessing_completeness.sh <production-directory> [report-directory] [reference-subdirectory] [run-list-file]
```

Exit codes: `0` complete, `1` missing/duplicate products, `2` usage or
filesystem error. Reports default to a new directory below the production
directory. An optional run-list excludes runs; each line may be `106250` or
`106250 - reason`. Reports include `summary.tsv`, `missing-*.txt`, and the
filtered `reference-runs.txt`. Directory symlinks are followed.

### Check if runs read from a run list are processed with evndis/mscw

```bash
./check_evndisp_mscw_processing.sh <run list>
```

### Temporary-directory file handling

```bash
./prepro_check_and_move_anasum_files.sh
./prepro_check_and_move_v2dl3_files.sh [batch-size]
```

The DL3 mover processes 1000 logs per batch by default; use a batch size from 1
to 1000 to change this.
