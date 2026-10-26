#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d "build/轻绘.app" ]]; then ./scripts/build.sh; fi
open "build/轻绘.app" "$@"
