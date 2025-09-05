#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

test_runner_client_token=$1
if [[ -z "${test_runner_client_token// }" ]]; then
    test_runner_client_token=$(security find-generic-password -w -s 'swift-provider-e2e' -a 'confidence-test')
fi

(cd $root_dir && \
    TEST_RUNNER_CLIENT_TOKEN=$test_runner_client_token TEST_RUNNER_TEST_FLAG_NAME=$2 xcodebuild \
        -quiet \
        -scheme Confidence-Package \
        -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
        -only-testing:ConfidenceTests/ConfidenceIntegrationTests \
        test) 