#!/bin/bash
set -euo pipefail

curdir="$(dirname "$(readlink -f "$0")")"
exec "$curdir/install" "$@"
