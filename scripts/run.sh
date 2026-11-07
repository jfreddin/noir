#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export NOIR_HELPER="$root/helper/catalog.py"
export NOIR_PYTHON="$root/runtime/bin/python"
exec "$root/build/noir" "$@"
