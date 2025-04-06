#!/bin/bash
# Pack dl3 directories into tar packages
#

VERSION="2025-03-21-v4.2"
LDIR=$(find . -maxdepth 1 -type d -name 'dl3*' ! -name '*all-events*')

echo "Pack DL3 for version $VERSION"

for L in $LDIR
do
    echo "Packing $L"
    tar -czf ${L}-${VERSION}.tar.gz ${L} &
done
