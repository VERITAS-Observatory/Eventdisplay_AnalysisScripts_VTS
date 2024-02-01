#!/bin/bash
# Pack log files in production directories into
# individual tar ball depending on the data level
#

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
echo "
Pack Eventdisplay log files for each data level.

./pack_log_files.sh <production directory>

Production directory is e.g., $VERITAS_DATA_DIR/processed_data_v490/AP/

"
exit
fi


PDIR="${1}"
DLIST="pack_log_files_sub_dir.dat"

DDIRS=$(cat "$DLIST")

cd "${PDIR}"

for DIR in $DDIRS; do
    echo $DIR
    rm -f logs_${DIR}.tar.gz
    find ${DIR} -type f -name "*.log" -exec tar -rf logs_${DIR}.tar.gz {} +
done
