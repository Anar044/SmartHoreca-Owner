#!/usr/bin/env python3
"""Set a readable launcher name on fresh Flutter Android/iOS runners.

The application and bundle IDs are deliberately left untouched here.
Changing an installed Android applicationId resets local app data; App Store
Connect requires the final Apple bundle ID to be agreed and registered first.
"""
from __future__ import annotations

from pathlib import Path
import plistlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
NAME = "SH Owner"

android = ROOT / "android/app/src/main/AndroidManifest.xml"
ios = ROOT / "ios/Runner/Info.plist"

if android.exists():
    source = android.read_text(encoding="utf-8")
    updated, count = re.subn(
        r'android:label="[^"]+"',
        'android:label="' + NAME + '"',
        source, count=1,
    )
    if count != 1:
        sys.exit("AndroidManifest is missing application label")
    android.write_text(updated, encoding="utf-8")
    print("Android launcher label:", NAME)

if ios.exists():
    with ios.open("rb") as file:
        data = plistlib.load(file)
    data["CFBundleDisplayName"] = NAME
    data["CFBundleName"] = NAME
    # FirebaseMessaging native iOS uses Apple Push Notification service.
    # Capability and provisioning still must be configured in Apple portal.
    modes = list(data.get("UIBackgroundModes", []))
    if "remote-notification" not in modes:
        modes.append("remote-notification")
    data["UIBackgroundModes"] = modes
    with ios.open("wb") as file:
        plistlib.dump(data, file, fmt=plistlib.FMT_XML, sort_keys=False)
    print("iOS home screen display name:", NAME)

    # FlutterFire iOS SDKs require modern iOS deployment targets.
    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        pod = podfile.read_text(encoding="utf-8")
        platform = "platform :ios, '15.0'"
        updated, found = re.subn(
            r"(?m)^\s*#?\s*platform\s+:ios,\s*['\"][0-9.]+['\"]",
            platform, pod, count=1,
        )
        if not found:
            updated = platform + "\n" + pod
        podfile.write_text(updated, encoding="utf-8")
    pbx = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    if pbx.exists():
        project = pbx.read_text(encoding="utf-8")
        project = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;",
                         "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", project)
        pbx.write_text(project, encoding="utf-8")

if not android.exists() and not ios.exists():
    sys.exit("Run flutter create . --platforms=android,ios first")
