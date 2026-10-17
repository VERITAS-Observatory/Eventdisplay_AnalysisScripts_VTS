#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <V2DL3 source checkout> [output directory]" >&2
    exit 2
fi

SOURCE=$(realpath "$1")
OUTPUT_DIR=${2:-${VERITAS_DATA_DIR:?Set VERITAS_DATA_DIR or pass an output directory}/shared/APPTAINERS}
APPTAINER=${APPTAINER:-apptainer}
[[ -f "$SOURCE/pyproject.toml" ]] || { echo "No pyproject.toml in $SOURCE" >&2; exit 1; }
command -v "$APPTAINER" >/dev/null || { echo "Apptainer not found: $APPTAINER" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required to build the wheel" >&2; exit 1; }

REVISION=$(git -C "$SOURCE" rev-parse --short=12 HEAD)
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
IMAGE="$OUTPUT_DIR/v2dl3-eventdisplay-${REVISION}.sif"
MANIFEST="${IMAGE%.sif}.manifest"
if [[ -e "$IMAGE" ]]; then
    echo "Runtime already exists: $IMAGE" >&2
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
python3 -m pip wheel --no-deps --wheel-dir "$WORK" "$SOURCE"
WHEEL=$(find "$WORK" -maxdepth 1 -name 'v2dl3-*.whl' -print -quit)
[[ -n "$WHEEL" ]] || { echo "V2DL3 wheel build failed" >&2; exit 1; }
WHEEL_NAME=$(basename "$WHEEL")

cat > "$WORK/v2dl3.def" <<EOF
Bootstrap: docker
From: python:3.11-slim

%files
    $WHEEL /opt/$WHEEL_NAME

%post
    python -m pip install --no-cache-dir /opt/$WHEEL_NAME
    python -m pip check
    python -m compileall -q /usr/local/lib/python3.11/site-packages/pyV2DL3
    rm -f /opt/$WHEEL_NAME
EOF

"$APPTAINER" build --fakeroot "$WORK/runtime.sif" "$WORK/v2dl3.def"
"$APPTAINER" exec "$WORK/runtime.sif" sh -ec '
    command -v v2dl3-eventdisplay-query-runparameters >/dev/null
    v2dl3-eventdisplay --help >/dev/null
    python -c "import pyV2DL3.script.eventdisplay_query_runparameters"
'
mv "$WORK/runtime.sif" "$IMAGE"
{
    echo "V2DL3 source: $SOURCE"
    echo "V2DL3 revision: $(git -C "$SOURCE" rev-parse HEAD)"
    echo "Python base: python:3.11-slim"
    echo "Built: $(date -u +%FT%TZ)"
    sha256sum "$IMAGE"
    "$APPTAINER" exec "$IMAGE" python -m pip freeze
} > "$WORK/manifest"
mv "$WORK/manifest" "$MANIFEST"
echo "Runtime: $IMAGE"
echo "Manifest: $MANIFEST"
