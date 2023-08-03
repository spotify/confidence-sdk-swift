#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

# Set the client token in your local keychain using the following command:
# security add-generic-password -s 'Swift Provider - E2E Tests'  -a 'konfidens-e2e' -w 'TOKEN'
# You can then run the script with no arguments - you will need to allow access the first time only.
test_runner_client_token=$1
if [[ -z "${test_runner_client_token// }" ]]; then
    test_runner_client_token=$(security find-generic-password -w -s 'Swift Provider - E2E Tests' -a 'konfidens-e2e')
fi

(cd $root_dir &&
    TEST_RUNNER_CLIENT_TOKEN=$test_runner_client_token TEST_RUNNER_TEST_FLAG_NAME=$2 xcodebuild \
        -scheme ConfidenceProvider \
        -sdk "iphonesimulator" \
        -destination 'platform=iOS Simulator,name=iPhone 14 Pro,OS=16.2' \
        test)
