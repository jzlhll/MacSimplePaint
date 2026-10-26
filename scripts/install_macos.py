#!/usr/bin/env python3
"""构建并安装固定证书签名的轻绘，保留运行中的其他副本。"""

import argparse
from pathlib import Path
import plistlib
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
    source = ROOT / "build/轻绘.app"
    destination = Path("/Applications/轻绘.app")
    verify(source, identity, bundle_id)
    if destination.is_symlink():
        raise SystemExit("Refusing to replace an app symlink")
    if destination.exists():
        info = plistlib.loads((destination / "Contents/Info.plist").read_bytes())
        if info.get("CFBundleIdentifier") != bundle_id:
            raise SystemExit("Refusing to replace an unrelated application")
        # 只检查安装目录下的实例，不关闭用户仍在编辑的开发或预览副本。
        running = subprocess.run(["/usr/bin/pgrep", "-f", "^/Applications/轻绘.app/Contents/MacOS/MacSimplePaint($| )"],
                                 capture_output=True)
        if running.returncode == 0:
            raise SystemExit("Save documents and quit the installed app before updating")
        if running.returncode != 1:
            raise SystemExit("Cannot determine whether the installed app is running")
    with tempfile.TemporaryDirectory(prefix=".macsimplepaint-install-", dir="/Applications") as temporary:
        staging = Path(temporary) / "轻绘.app"
        backup = Path(temporary) / "Previous.app"
        shutil.copytree(source, staging)
        verify(staging, identity, bundle_id)
        had_previous = destination.exists()
        if had_previous:
            destination.rename(backup)
        try:
            staging.rename(destination)
            verify(destination, identity, bundle_id)
        except BaseException:
            if destination.exists():
                shutil.rmtree(destination)
            if backup.exists():
                backup.rename(destination)
            raise
    # 更新包目录时间并强制注册新的图标资源信息。
    destination.touch()
    register = Path("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
    subprocess.run([str(register), "-f", str(destination)], check=True)
    print("Installed: " + str(destination))
    print("Signing certificate: " + identity)


if __name__ == "__main__":
    main()
