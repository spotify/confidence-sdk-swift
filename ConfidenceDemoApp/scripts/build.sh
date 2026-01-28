#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"
repo_root="$script_dir/../../"

SIMULATOR=$(xcrun simctl list devices available -j | \
    python3 "$repo_root/.github/scripts/find-simulator.py" iOS)

echo "Using simulator: $SIMULATOR"

(cd $root_dir &&
    xcodebuild \
        -quiet \
        -scheme ConfidenceDemoApp \
        -destination "id=$SIMULATOR" )
