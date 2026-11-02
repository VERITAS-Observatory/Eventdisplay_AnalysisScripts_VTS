#!/bin/bash
# Pack dl3 directories into tar packages
#

if [[ $# -ne 1 || -z "$1" ]]; then
    echo "Usage: $0 VERSION" >&2
    exit 1
fi

VERSION="$1"

echo "Pack DL3 for version $VERSION"

status=0
while IFS= read -r -d '' L; do
    # Package each immediate subdirectory (for example, runs 3 through 11).
    while IFS= read -r -d '' D; do
        PACKAGE="${L}-$(basename "$D")-${VERSION}.tar.gz"
        echo "Packing $D into $PACKAGE"
        tar -czf "$PACKAGE" "$D" || status=1
    done < <(find "$L" -mindepth 1 -maxdepth 1 -type d -print0)
done < <(find . -maxdepth 1 -type d -name 'dl3*' ! -name 'dl3_archive*' -print0)

exit "$status"
