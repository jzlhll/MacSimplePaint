#!/usr/bin/env python3
"""构建并安装固定证书签名的轻绘，保留运行中的其他副本。"""

import argparse
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

from sign_macos import load_signing, verify

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    if not args.skip_build:
        subprocess.run([str(ROOT / "scripts/build.sh")], check=True)
    identity, bundle_id = load_signing()
    source = ROOT / "build/SimplePaint.app"
    destination = Path("/Applications/SimplePaint.app")
    verify(source, identity, bundle_id)
    register = Path("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
    previous_apps = []
    for app in [destination, Path("/Applications/MacSimplePaint.app"), Path("/Applications/轻绘.app")]:
        if app.is_symlink():
            raise SystemExit("Refusing to replace an app symlink: " + str(app))
        if not app.exists():
            continue
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        if info.get("CFBundleIdentifier") != bundle_id:
            raise SystemExit("Refusing to replace an unrelated application: " + str(app))
        # 只检查安装目录下的实例，不关闭用户仍在编辑的开发或预览副本。
        executable = app / "Contents/MacOS/MacSimplePaint"
        running = subprocess.run(["/usr/bin/pgrep", "-f", "^" + re.escape(str(executable)) + "($| )"],
                                 capture_output=True)
        if running.returncode == 0:
            raise SystemExit("Save documents and quit the installed app before updating")
        if running.returncode != 1:
            raise SystemExit("Cannot determine whether the installed app is running")
        previous_apps.append(app)
    with tempfile.TemporaryDirectory(prefix=".macsimplepaint-install-", dir="/Applications") as temporary:
        staging = Path(temporary) / "SimplePaint.app"
        shutil.copytree(source, staging)
        verify(staging, identity, bundle_id)
        backups = []
        installed = False
        try:
            for app in previous_apps:
                if app != destination:
                    subprocess.run([str(register), "-u", str(app)], check=True)
                backup = Path(temporary) / ("Previous-" + app.name)
                app.rename(backup)
                backups.append((app, backup))
            staging.rename(destination)
            installed = True
            verify(destination, identity, bundle_id)
        except BaseException:
            if installed and destination.exists():
                shutil.rmtree(destination)
            for app, backup in reversed(backups):
                backup.rename(app)
            raise
    # 更新包目录时间并强制注册新的图标资源信息。
    destination.touch()
    subprocess.run([str(register), "-f", str(destination)], check=True)
    print("Installed: " + str(destination))
    print("Signing certificate: " + identity)


if __name__ == "__main__":
    main()
