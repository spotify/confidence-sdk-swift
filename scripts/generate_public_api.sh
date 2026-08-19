#!/bin/bash

set -e

script_dir=$(dirname $0)
root_dir="$script_dir/../"

# exit if param is not supplied
if [ -z "$1" ]; then
    echo "Please provide the module name as a parameter."
    exit 1
fi
MODULE=$1 

SIMULATOR=$(xcrun simctl list devices available -j | \
    python3 "$root_dir/.github/scripts/find-simulator.py" iOS)

echo "Using simulator: $SIMULATOR"

# Generate the json file with:
sourcekitten doc --module-name ${MODULE} -- -scheme Confidence-Package -destination "id=$SIMULATOR" > $script_dir/${MODULE}_raw_api.json

# Extract the public API from the raw api json file
python3 $script_dir/extract_public_funcs.py $script_dir/${MODULE}_raw_api.json $root_dir/api/${MODULE}_public_api.json

# Clean up the raw api json file
rm $script_dir/${MODULE}_raw_api.json
