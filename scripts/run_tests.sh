#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

(cd $root_dir &&
    xcodebuild \
        -scheme KonfidensProvider \
        -sdk "iphonesimulator" \
        -destination 'platform=iOS Simulator,name=iPhone 14 Pro,OS=16.0' \
        test)
