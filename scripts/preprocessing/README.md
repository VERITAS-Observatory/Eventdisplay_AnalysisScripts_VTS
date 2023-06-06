# Scripts for VERITAS Archival preprocessing

This directory contains scripts useful for the preprocessing of data at DESY.

## Run list preparation

Obtain run list from files on disk with a very simple selection of runs using the DQM information:
```
./prepare_runlist_after_dqm.sh $VERITAS_DATA_DIR/DBTEXT/ "*.tar.gz" .tar.gz \
        $EVNDISPSYS/../EventDisplay_Release_v490/preprocessing/runlists_good_observation_runs/removed_runs.dat
```


## Data product packing

Pack files for a certain data type:
e.g., 
```
./pack_data_files.sh mscw tmp_packing/22s.list 22s
```

Uploading to DESY cloud:

e.g.
```
curl -u username -T 10.tar.gz \
    "https://syncandshare.desy.de/remote.php/dav/files/username/Shared/VTS/22s/10.tar.gz"
```
