# DB scripts to save run-wise information 

Information is saved in in comma-separated files in `$VERITAS_DATA_DIR/DBTEXT/`.

Usages:

Query information for a single run:
```
./db_run.sh <run number>
```

Query information for a list of run (simple format with one column of run numbers):
```
./query_run_list.sh <run list>
```

Files are downloaded and saved in individual small files. They should be tar-packaged 
with the script:
```
db_pack_new_directories.sh
```
(new directories need to be deleted by hand after packing)
