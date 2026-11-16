#!/bin/bash
set -euo pipefail
# Accept an explicit destination locally; CI chooses a simulator by device family.
DEVICE_FAMILY="${DEVICE_FAMILY:-iPhone}"
if [[ -z "${SIMULATOR_ID:-}" ]]; then
    SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
family = sys.argv[1]
data = json.load(sys.stdin)
for runtime, devices in sorted(data["devices"].items(), reverse=True):
    if ".iOS-" not in runtime:
        continue
    for device in devices:
        if device["name"].startswith(family):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available simulator for " + family)
' "$DEVICE_FAMILY")
fi
xcodebuild -version
xcodebuild \
    -project LifeLoop/LifeLoop.xcodeproj \
    -scheme LifeLoop \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
    -derivedDataPath "${DERIVED_DATA_PATH:-/tmp/lifeloop-derived-data}" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO test
