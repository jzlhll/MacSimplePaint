#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d "build/SimplePaint.app" ]]; then ./scripts/build.sh; fi
open "build/SimplePaint.app" "$@"
