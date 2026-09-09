#!/bin/bash
# Bulk DBTEXT export wrapper. See db_bulk_export.py --help.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "${SCRIPT_DIR}/db_bulk_export.py" "$@"
