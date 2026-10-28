#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    echo "Usage: scripts/build.sh [debug|release]" >&2
    exit 1
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
python3 scripts/sign_macos.py --check
mkdir -p .build build
build_work="$(mktemp -d "$PWD/.build/paint-build.XXXXXX")"
trap 'rm -rf "$build_work"' EXIT
staged_app="$build_work/SimplePaint.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
optimization="-O"
if [[ "$configuration" == "debug" ]]; then optimization="-Onone"; fi
swiftc -swift-version 5 -parse-as-library "$optimization" -g \
    -target "$(uname -m)-apple-macosx13.0" -module-name MacSimplePaint \
    Sources/MacSimplePaint/*.swift -o "$staged_app/Contents/MacOS/MacSimplePaint" \
    -framework AppKit -framework ImageIO -framework UniformTypeIdentifiers
cp Resources/Info.plist "$staged_app/Contents/Info.plist"
# 图标名称随内容变化，让系统在更新应用后重新读取图标资源。
python3 - "$staged_app/Contents" <<'PYICON'
from pathlib import Path
import hashlib
import plistlib
import shutil
import sys

contents = Path(sys.argv[1])
artwork = Path("Resources/AppIcon.icns")
icon_name = "AppIcon-" + hashlib.sha256(artwork.read_bytes()).hexdigest()[:16] + ".icns"
shutil.copy2(artwork, contents / "Resources" / icon_name)
plist_path = contents / "Info.plist"
info = plistlib.loads(plist_path.read_bytes())
info["CFBundleIconFile"] = icon_name
plist_path.write_bytes(plistlib.dumps(info))
PYICON
for localization in Resources/*.lproj; do
    cp -R "$localization" "$staged_app/Contents/Resources/"
done
python3 scripts/sign_macos.py "$staged_app"
# 整包切换且保留旧文件，不能原地覆盖运行中进程所映射的签名代码页。
python3 scripts/publish_build.py "$staged_app"
