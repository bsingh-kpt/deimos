#!/bin/bash

set -xeuo pipefail

[[ -z "$1" ]] && { echo "Error: missing base dir" >&2; exit 1; } 

export BASE_DIR="$1"
export THIRDPARTY_DIR="$BASE_DIR/thirdparty"
export DEFINITIONS_DIR="$BASE_DIR/definitions"
export ASSETS_DIR="$BASE_DIR/assets"

# shellcheck source=/dev/null
source "$BASE_DIR/scripts/common.sh"

# Create a unique temp workspace for this run
TMP_WORK_DIR=$(mktemp -d -t build-assets-XXXXXXXXXX)
export TMP_WORK_DIR

# SET THE TRAP: Cleanup will run on exit, error, or interruption
trap cleanup EXIT SIGINT SIGTERM ERR

# Install definitions
for def_file in "$BASE_DIR/definitions"/*.txt; do
    type=$(basename "$def_file" .txt)
    handler_func="install_$type"
    
	# shellcheck source=/dev/null
    source "$BASE_DIR/scripts/install-${type}.sh"

    if declare -f "$handler_func" > /dev/null; then
        log_info "--- Starting $handler_func ---"
        "$handler_func" "$def_file"
	else
		log_warn "$handler_func not defined. Skipping $def_file"
    fi
done
