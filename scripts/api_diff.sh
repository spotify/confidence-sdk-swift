#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

# Generate the json file with:
sourcekitten doc --module-name Confidence -- -scheme Confidence-Package -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' > $script_dir/raw_api.json

# Extract the public API from the raw api json file
python3 $script_dir/extract_public_funcs.py $script_dir/raw_api.json $script_dir/current_public_api.json

# Clean up the raw api json file
rm $script_dir/raw_api.json

# Compare the public API with the previous public API and exit with 1 if there are changes
# TODO(nicklasl): store the result (exit code) and provide information on how to remedy.
git diff --no-index --exit-code $script_dir/public_api.json $script_dir/current_public_api.json