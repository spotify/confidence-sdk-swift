#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

(cd $root_dir && \
    xcodebuild \
        -quiet \
        -scheme Confidence-Package \
        -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
        -skip-testing:ConfidenceTests/ConfidenceIntegrationTests \
        test)
