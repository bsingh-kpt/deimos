#!/bin/bash

# Standardized logging
log_info() { echo -e "\e[34m[INFO]\e[0m  $1"; }
log_ok() { echo -e "\e[32m[OK]\e[0m    $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_warn() { echo -e "\e[33m[WARN]\e[0m  $1"; }

trim() { echo "$1" | xargs; }

# Download: Only fetches the file
download_archive() {
	local url=$1
	local save_path=$2
	local expected_hash=$3

	url="${url//\$\{ASSETS_DIR\}/$ASSETS_DIR}"
	url="${url//\$\{THIRDPARTY_DIR\}/$THIRDPARTY_DIR}"

	# 1. Handle Local Files
	if [[ "$url" == local://* ]]; then
		# Remove the 'local://' prefix to get the actual path
		# Assuming the path is relative to the repo root or an absolute path in the container
		local actual_path="${url#local://}"

		log_info "Copying local file: $actual_path"

		if [[ -f "$actual_path" ]]; then
			cp "$actual_path" "$save_path"
		else
			log_error "Local file not found: $actual_path"
			return 1
		fi

	# 2. Handle Remote Files
	else
		log_info "Downloading remote file: $url"
		if ! curl -fsSLo "$save_path" "$url"; then
			log_error "Download failed: $url"
			return 1
		fi
	fi

	# 3. Security Check: Verify Hash
	if [[ -n "$expected_hash" ]]; then
		if echo "$expected_hash  $save_path" | sha256sum -c --status; then
			log_ok "Integrity verified: $url"
			return 0
		else
			log_error "SECURITY ALERT: Hash mismatch for $url"
			# Remove the corrupted/compromised file
			rm -f "$save_path"
			return 1
		fi
	else
		log_warn "No checksum provided for $url. Skipping verification."
		return 0
	fi
}

# Install: Only extracts the file
install_archive() {
	local archive_path=$1
	local dest=$2
	local strip=$3

	mkdir -p "$dest"

	# Detect file type using the file mime-type or magic bytes
	# Since we saved as .tmp, we should check the actual file content or the original URL

	mime_type=$(file --mime-type -b "$save_path")

	case "$mime_type" in
	"application/x-rpm")
		log_info "Detected RPM format"
        local final_archive_path="${archive_path%.archive}.rpm"
        mv "$archive_path" "$final_archive_path"
		dnf5 install -y "$final_archive_path"
		;;

	"application/zip")
		log_info "Detected ZIP format"
        local final_archive_path="${archive_path%.archive}.zip"
        mv "$archive_path" "$final_archive_path"
		local zip_tmp
		zip_tmp=$(mktemp -d)

		if ! unzip -o -q "$final_archive_path" -d "$zip_tmp"; then
			return 1
		fi

		if [ "$strip" -eq 1 ]; then
			# Move the contents of the first inner directory to the destination
			# The '/*' glob finds the top-level folder inside the zip
			mv "$zip_tmp"/*/* "$dest/" 2>/dev/null || mv "$zip_tmp"/* "$dest/"
		else
			cp -r "$zip_tmp"/* "$dest/"
		fi

		rm -rf "$zip_tmp"
		;;

	"application/x-tar")
		log_info "Detected tar archive"
        local final_archive_path="${archive_path%.archive}.tar"
        mv "$archive_path" "$final_archive_path"
		tar -xf "$final_archive_path" -C "$dest" --strip-components="$strip"
		;;
    
    "application/gzip")
		log_info "Detected tar (gzip) archive"
        local final_archive_path="${archive_path%.archive}.tar.gz"
        mv "$archive_path" "$final_archive_path"
		tar -xzf "$final_archive_path" -C "$dest" --strip-components="$strip"
		;;

    "application/x-xz")
		log_info "Detected tar (xz) archive"
        local final_archive_path="${archive_path%.archive}.tar.xz"
        mv "$archive_path" "$final_archive_path"
		tar -xJf "$final_archive_path" -C "$dest" --strip-components="$strip"
		;;

	*)
		log_error "Unknown archive format for $archive_path : $mime_type"
		return 1
		;;
	esac

	return $?
}

# Cleanup: Automatically triggered
cleanup() {
	local exit_code=$?
	if [ -d "$TMP_WORK_DIR" ]; then
		log_info "Cleaning up temporary files..."
		rm -rf "$TMP_WORK_DIR"
	fi
	exit $exit_code
}

install_from_manifest() {
	local manifest="$1"

	# Use a while loop with a custom IFS to handle the pipe-delimited file
	grep -v '^#' "$manifest" | while IFS='|' read -r name version url target canonical strip hash; do

		# 1. Clean up the data (Trimming whitespace)
		name=$(trim "$name")
		version=$(trim "$version")
		url=$(trim "$url")
		target=$(trim "$target")
		canonical=$(trim "$canonical")
		strip=$(trim "$strip")
		hash=$(trim "$hash")

		# Skip empty lines
		[[ -z "$name" ]] && continue

		log_info "Processing: $name (v$version)"

		# 2. Define internal paths
		local save_path
		local final_dest
		if [[ -z "$canonical" ]]; then
			save_path="$TMP_WORK_DIR/${name// /_}-$version.archive"
			final_dest="${target}"
		else
			save_path="$TMP_WORK_DIR/$canonical-$version.archive"
			final_dest="${target}/${canonical}"
		fi

		# 3. Execution Flow: Download -> Verify -> Install -> Cleanup
		if download_archive "$url" "$save_path" "$hash"; then
			# Default strip to 0 if empty
			local strip_level="${strip:-0}"

			if install_archive "$save_path" "$final_dest" "$strip_level"; then
				log_ok "Successfully installed $name"
            else
                log_error "Failed installation for $name"
                continue
			fi

			# post-install
			local hook_name="post_install_${canonical//-/_}"
			if declare -f "$hook_name" >/dev/null; then
				log_info "Found post-install hook: $hook_name"
				# Pass the destination path to the hook so it knows where the files are
				"$hook_name" "$version" "$final_dest"
			fi

			# Cleanup the downloaded archive to keep /tmp lean
			rm -f "$save_path"
		fi
	done
}
