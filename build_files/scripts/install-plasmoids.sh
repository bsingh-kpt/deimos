#!/bin/bash

install_plasmoids() {
	local def_file=$1

	while IFS='|' read -r NAME VERSION URL TARGET_DIR CANONICAL_NAME STRIP CHECKSUM || [[ -n "$NAME" ]]; do
		local name
        local version
		local url
        local canon_name
		local strip
        local checksum
		local dest
		local archive_file

		# Skip comments/whitespace
		[[ "$(trim "$NAME")" =~ ^#.* ]] || [[ -z "$(trim "$NAME")" ]] && continue

		name=$(trim "$NAME")
        version=$(trim "$VERSION")
		url=$(trim "$URL")
        canon_name=$(trim "$CANONICAL_NAME")
		strip=$(trim "$STRIP")
        checksum=$(trim "$CHECKSUM")
		
        dest=$(trim "$TARGET_DIR")/$canon_name

		# Define a unique filename in the temp dir
		archive_file="$TMP_WORK_DIR/$canon_name-$version.tmp"

		log_info "Processing $name..."

		# Step 1: Download and Verify
		if download_archive "$url" "$archive_file" "$checksum"; then
			# Step 2: Install
			install_archive "$archive_file" "$dest" "$strip"
			# Optional: remove individual file after install to keep TMP_WORK_DIR small
			rm -f "$archive_file"
		fi

	done <"$def_file"
}
