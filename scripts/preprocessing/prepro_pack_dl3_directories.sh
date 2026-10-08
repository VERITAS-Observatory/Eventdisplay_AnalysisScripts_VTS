#!/bin/bash
# Pack dl3 directories into tar packages
#

if [[ $# -ne 1 || -z "$1" ]]; then
    echo "Usage: $0 VERSION" >&2
    exit 1
fi

VERSION="$1"
LDIR=$(find . -maxdepth 1 -type d -name 'dl3*' ! -name '*all-events*' ! -name 'dl3_archive*')

echo "Pack DL3 for version $VERSION"

for L in $LDIR
do
    echo "Packing $L"
    tar -czf "${L}-${VERSION}.tar.gz" "${L}" &
done
