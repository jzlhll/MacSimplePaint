#!/usr/bin/env python3
"""使用固定的本机证书签名并校验轻绘。"""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def load_signing():
    path = ROOT / ".local-signing.json"
    if not path.is_file():
        raise SystemExit("Local signing is not configured: " + str(path))
    config = json.loads(path.read_text())
    identity = config.get("identity", "")
    bundle_id = config.get("bundle_id", "")
    if not isinstance(identity, str) or not re.fullmatch(r"[0-9A-Fa-f]{40}", identity):
        raise SystemExit("Signing identity must be an exact certificate SHA-1 fingerprint")
    info = plistlib.loads((ROOT / "Resources/Info.plist").read_bytes())
    if bundle_id != info["CFBundleIdentifier"]:
        raise SystemExit("Signing configuration does not match the app bundle identifier")
    return identity.upper(), bundle_id


def requirement(identity, bundle_id):
    return '=identifier "' + bundle_id + '" and certificate leaf = H"' + identity + '"'


def verify(app, identity, bundle_id):
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", "-R",
                    requirement(identity, bundle_id), str(app)], check=True)
    result = subprocess.run(["/usr/bin/codesign", "--display", "-r", "-", str(app)],
                            check=True, capture_output=True, text=True)
    text = result.stdout + result.stderr
    if "designated =>" not in text or "cdhash" in text:
        raise SystemExit("Expected a stable certificate-based designated requirement")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path, nargs="?")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    identity, bundle_id = load_signing()
    if args.check:
        result = subprocess.run(["/usr/bin/security", "find-identity", "-v", "-p", "codesigning"],
                                check=True, capture_output=True, text=True)
        identities = re.findall(r'\d+\) ([0-9A-Fa-f]{40}) "[^"\n]+"', result.stdout)
        if identity not in {value.upper() for value in identities}:
            raise SystemExit("Pinned signing certificate is unavailable; ad hoc signing is disabled: " + identity)
        print("Signing certificate available: " + identity)
        return
    if args.app is None:
        parser.error("app is required unless --check is used")
    app = args.app.resolve()
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != bundle_id:
        raise SystemExit("Refusing to sign an app with a different bundle identifier")
    if not args.verify:
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", identity,
                        "--identifier", bundle_id, "--options", "runtime", "--timestamp=none", str(app)], check=True)
    verify(app, identity, bundle_id)
    print("Verified certificate signature: " + str(app))


if __name__ == "__main__":
    main()
