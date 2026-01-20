#!/bin/bash

# Standardized logging
log_info()  { echo -e "\e[34m[INFO]\e[0m  $1"; }
log_ok()    { echo -e "\e[32m[OK]\e[0m    $1"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m  $1"; }

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

    # Detect file type using the file extension or magic bytes
    # Since we saved as .tmp, we should check the actual file content or the original URL
    if file "$archive_path" | grep -q "Zip archive"; then
        log_info "Detected ZIP format"
        local zip_tmp
        zip_tmp=$(mktemp -d)
        
        unzip -q "$archive_path" -d "$zip_tmp"
        
        if [ "$strip" -eq 1 ]; then
            # Move the contents of the first inner directory to the destination
            # The '/*' glob finds the top-level folder inside the zip
            mv "$zip_tmp"/*/* "$dest/" 2>/dev/null || mv "$zip_tmp"/* "$dest/"
        else
            cp -r "$zip_tmp"/* "$dest/"
        fi
        rm -rf "$zip_tmp"

    elif file "$archive_path" | grep -q "gzip compressed"; then
        log_info "Detected GZIP (tar) format"
        tar -xzf "$archive_path" -C "$dest" --strip-components="$strip"
    
    elif file "$archive_path" | grep -q "XZ compressed"; then
        log_info "Detected XZ (tar) format"
        tar -xJf "$archive_path" -C "$dest" --strip-components="$strip"
    else
        log_error "Unknown archive format for $archive_path"
        return 1
    fi

    log_ok "Installation complete for $(basename "$archive_path")"
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