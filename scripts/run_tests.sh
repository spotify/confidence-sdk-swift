#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"
platform=${1:-iOS}

SIMULATOR=$(xcrun simctl list devices available -j | \
    python3 "$root_dir/.github/scripts/find-simulator.py" "$platform")

echo "Using simulator: $SIMULATOR"

test_arguments=(-skip-testing:ConfidenceTests/ConfidenceIntegrationTests)
if [[ "$platform" == "watchOS" ]]; then
    test_arguments=(-only-testing:ConfidenceProviderTests/WatchOSSmokeTests)
fi

(cd $root_dir && \
    xcodebuild \
        -scheme Confidence-Package \
        -destination "id=$SIMULATOR" \
        "${test_arguments[@]}" \
        test)
