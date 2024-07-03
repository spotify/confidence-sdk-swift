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
echo "Comparing genereated public API with previous public API"
set +e
git diff --no-index --exit-code $script_dir/public_api.json $script_dir/current_public_api.json
# Capture the exit code of the git diff command
diff_exit_code=$?
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
printf "\n"

if [ $diff_exit_code -eq 0 ]; then
    printf "${GREEN}No changes detected in the public API.${NC}"
else
    printf "${RED}Changes detected in the public API. Please review the differences.\n
If the changes are _intended_, please update the public API by running the generate_public_api_list.sh script and commit the changes to public_api.json.\n
If the changes are unintended, please investigate the changes and update the source code accordingly.${NC}"
fi

# Clean up the current public api json file
rm $script_dir/current_public_api.json

# Exit with the diff's exit code to maintain the intended behavior
exit $diff_exit_code