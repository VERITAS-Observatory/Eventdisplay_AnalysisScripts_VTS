# DB scripts to save run-wise information

Scripts to query the VERITAS database for run-wise information and save it in
several text files per run. The Eventdisplay analysis code can use those files instead of directly querying the database. The information is saved in a tar file of comma-separated files in `$VERITAS_DATA_DIR/shared/DBTEXT/`.
Allows also to convert the csv files into FITS tables.

Note that the scripts are not optimized for optimal querying time, but for simplicity.

Usages:

Make sure that the environment is set up correctly:

```bash
export VERITAS_DATA_DIR=<your data directory>
```

The database text files (called 'DBTEXT files') are saved in the directory `$VERITAS_DATA_DIR/shared/DBTEXT/`.

Query information for a single run:

```bash
./db_run.sh <run number>
```

Query information for a list of run (simple format with one column of run numbers):

```bash
./query_run_list.sh <run list>
```

Files are downloaded and saved in individual small files. They should be tar-packaged
with the script:

```bash
./db_pack_new_directories.sh
```

(new directories need to be deleted by hand after packing)

Before packaging, each run directory receives a `<run>.metadata.json` manifest.
The manifest records the extraction times, database-server UTC timestamps, file
sizes and UTC modification times, and SHA-256 checksums for all payload files.
The manifest itself is included in the tar package and is excluded from its own
checksum list. Packages created before this metadata support need to be
re-read/repacked (or migrated separately) to receive a manifest.

To use this in `evndisp`, add a command line parameter `-dbtextdirectory $VERITAS_DATA_DIR/shared/DBTEXT/<run>`. The analysis script `ANALYSIS.evndisp.sh` will automatically use the DBTEXT files if they are present.

## Old (V4) laser runs without database entries

Very old (V4) observations don't have laser runs assigned in the DB entries.
Use this script to find the corresponding laser run for an observation run and
write a `.laserrun` file:

```bash
./db_update_old_laser_files.sh 32987 laser_runs
```

The file `laser_runs` is the same as used for loggen and contains for each observation
night the corresponding laser run.

## DQM Information for DL3

The python script `db_write_fits.py` allows to read the DB text files and write it in form of tables into a FITS file.
This script also summarizes basic data quality information for each run and writes it into a separate FITS tables named `DQM`.
The script `db_combine_dqm_fits.py` allows to combine a large number of DQM tables into one single table.

Observe that these python scripts require the packages installed as outlined in the environment file `./environment.yml`.
