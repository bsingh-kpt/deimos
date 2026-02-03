#!/bin/bash

install_packages() {
	log_info "--- Starting Packages Installation ---"
	install_from_manifest "$1"
}
