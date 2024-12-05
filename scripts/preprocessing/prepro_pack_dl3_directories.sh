#!/bin/bash
# Pack dl3 directories into tar packages
#

VERSION="2024-11-30-v4.0"
LDIR=$(find . -maxdepth 1 -type d -name 'dl3*' ! -name '*all-events*')

echo "Pack DL3 for version $VERSION"

for L in $LDIR
do
    echo "Packing $L"
    tar -czf ${L}-${VERSION}.tar.gz ${L} &
done
