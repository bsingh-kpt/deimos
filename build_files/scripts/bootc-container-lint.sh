#!/bin/bash
# SPDX-FileCopyrightText: Timothée Ravier <tim@siosm.fr>
# SPDX-License-Identifier: CC0-1.0

set -euxo pipefail

target="/tmp/target"

source /etc/os-release

declare -a args=()

if [[ "${NAME}" == "secureblue" ]]; then
    args+=("--skip" "nonempty-run-tmp")
fi

bootc container lint --fatal-warnings --no-truncate --rootfs "$target" "${args[@]}"
