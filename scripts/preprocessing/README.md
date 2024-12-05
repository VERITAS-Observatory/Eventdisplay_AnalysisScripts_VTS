# Scripts for VERITAS Archival preprocessing

This directory contains scripts useful for the preprocessing of data at DESY.

## Run list preparation

Requires that DBTEXT files are downloaded for all runs under consideration.

Obtain run list from files on disk with a selection of runs using the DQM information:

```bash
./prepare_runlist_after_dqm.sh $VERITAS_DATA_DIR/DBTEXT/ "*.tar.gz" .tar.gz \
        $EVNDISPSYS/../EventDisplay_Release_v490/preprocessing/runlists_good_observation_runs/runs_not_processed.dat > dqm.log
```

This will take some time.

To get all runs with `do_not_use` flag: `grep "do_not_use (STATUS CUT APPLIED)" dqm.log`.

## Data product packing

Pack files for a certain data type:
e.g.,

```bash
./pack_data_files.sh mscw tmp_packing/22s.list 22s
```

Uploading to DESY cloud:

e.g.

```bash
curl -u username -T 10.tar.gz \
    "https://syncandshare.desy.de/remote.php/dav/files/username/Shared/VTS/22s/10.tar.gz"
```

## Checking preprocessed files for errors and moving of files

### Move files for all data products from list of runs

Move Eventdisplay data products from all stages into an runs_with_issues directory.

```bash
./archive_error_files.sh <run list>
```

### Check number of DL3 fits and log files for all cuts and analysis types.

```bash
./check_dl3_number_of_files_per_cut.sh <directory>
```

### Check if runs read from a run list are processed with evndis/mscw

```bash
./check_evndisp_mscw_processing.sh <run list>
```

### Scripts for tmp directory file handling

These are all files staring with `prepro_`:

```bash
./prepro_check_and_move_anasum_files.sh
./prepro_check_and_move_v2dl3_files.sh
```
