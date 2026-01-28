#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

SIMULATOR=$(xcrun simctl list devices available -j | \
    python3 "$root_dir/.github/scripts/find-simulator.py" iOS)

echo "Using simulator: $SIMULATOR"

(cd $root_dir && \
    xcodebuild \
        -scheme Confidence-Package \
        -destination "id=$SIMULATOR" \
        -skip-testing:ConfidenceTests/ConfidenceIntegrationTests \
        test)
