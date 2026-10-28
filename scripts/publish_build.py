#!/usr/bin/env python3
"""发布已完成签名的构建产物，保留旧包以保护运行中的代码映射。"""

from pathlib import Path
import sys
import uuid

root = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1]).resolve()
output = root / "build/SimplePaint.app"
retired = root / ".build/retired-apps"
backup = retired / ("SimplePaint-" + uuid.uuid4().hex + ".app")
if output.is_symlink():
    raise SystemExit("Refusing to replace an app symlink")
if output.exists():
    retired.mkdir(parents=True, exist_ok=True)
    output.rename(backup)
try:
    source.rename(output)
except BaseException:
    if backup.exists():
        backup.rename(output)
    raise
print("Built: " + str(output))
if backup.exists():
    print("Previous build preserved: " + str(backup))
