#!/bin/bash
# SPDX-FileCopyrightText: Timothée Ravier <tim@siosm.fr>
# SPDX-License-Identifier: CC0-1.0

set -euxo pipefail

kver=$(cd "/usr/lib/modules" && echo *)

# Remove the initramfs from the base image. We'll rebuilt it in a later stage
# for each GPU vendor target and include it in the UKI.
rm "/usr/lib/modules/$kver/initramfs.img"

# Remove the kernel from the base image as we made a copy in another stage. It
# will be included in the UKI in a later stage.
rm "/usr/lib/modules/$kver/vmlinuz"

mkdir -p /usr/lib/ostree/
cat <<'EOF' >/usr/lib/ostree/prepare-root.conf
[composefs]
enabled = yes
[sysroot]
readonly = true
EOF

### CLEANUP IMAGE ###
# clear machine id so systemd will generate new on first boot
: > /etc/machine-id
# clean /var except /var/tmp
find /var -mindepth 1 -maxdepth 1 ! -name tmp -exec rm -rf {} +
# clean any ssh_host_* keys
find /etc/ssh/ -name ssh_host_* -exec echo rm -f {} +
### CLEANUP IMAGE ###
