#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

# Generate the json file with:
sourcekitten doc --module-name Confidence -- -scheme Confidence-Package -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' > $script_dir/raw_api.json

# Extract the public API from the raw api json file
python3 $script_dir/extract_public_funcs.py $script_dir/raw_api.json $root_dir/api/public_api.json

# Clean up the raw api json file
rm $script_dir/raw_api.json