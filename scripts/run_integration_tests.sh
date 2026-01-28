#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

test_runner_client_token=$1
if [[ -z "${test_runner_client_token// }" ]]; then
    test_runner_client_token=$(security find-generic-password -w -s 'swift-provider-e2e' -a 'confidence-test')
fi

SIMULATOR=$(xcrun simctl list devices available -j | \
    python3 "$root_dir/.github/scripts/find-simulator.py" iOS)

echo "Using simulator: $SIMULATOR"

(cd $root_dir && \
    TEST_RUNNER_CLIENT_TOKEN=$test_runner_client_token TEST_RUNNER_TEST_FLAG_NAME=$2 xcodebuild \
        -quiet \
        -scheme Confidence-Package \
        -destination "id=$SIMULATOR" \
        -only-testing:ConfidenceTests/ConfidenceIntegrationTests \
        test)
