#!/bin/bash
# SPDX-FileCopyrightText: Timothée Ravier <tim@siosm.fr>
# SPDX-License-Identifier: CC0-1.0

# The sections inside the if conditionals are intentionally not properly
# indented to make the heredoc blocks easier to read.

set -euxo pipefail

# We can not ship openh264 in the image
rm -f "/etc/yum.repos.d/fedora-cisco-openh264.repo"

# Install fsverity utils to make it easier to check things
# Install systemd-boot (will be replaced by the signed version in a later stage)
dnf install -y fsverity-utils systemd-boot-unsigned

# Remove rpm-ostree and the backends in GNOME Software and Plasma Discover
dnf remove -y \
    rpm-ostree \
    rpm-ostree-libs \
    gnome-software-rpm-ostree \
    plasma-discover-rpm-ostree

# Install latest bootc release
dnf upgrade -y --enablerepo=updates-testing --refresh bootc

# Uninstall bootupd (no support for systemd-boot yet)
rpm -e bootupd
rm -vrf "/usr/lib/bootupd"
# Legacy ostree folder
rm -vrf "/usr/lib/ostree-boot"
# Remove GRUB2
grub_packages=(
    "grub2-common"
    "grub2-efi-x64"
    "grub2-pc"
    "grub2-pc-modules"
    "grub2-tools"
    "grub2-tools-minimal"
)
if [[ "$(rpm -qa | grep -c grub2-efi-ia32)" -ne 0 ]]; then
    grub_packages+=("grub2-efi-ia32")
fi
rpm -e --nodeps "${grub_packages[@]}"


if rpm -q --quiet fedora-release-identity-basic; then

# bootc base images
cat > "/usr/lib/bootc/install/80-rootfs.toml" << 'EOF'
# Default to ext4
[install.filesystem.root]
type = "ext4"
EOF

else

# All Atomic Desktops
cat > "/usr/lib/bootc/kargs.d/10-rootfs.toml" << 'EOF'
# Mount the root filesystem read-write
# Enable btrfs compression
kargs = ["rw", "rootflags=compress=zstd:1"]
EOF

cat > "/usr/lib/bootc/install/80-rootfs.toml" << 'EOF'
# Default to btrfs
[install.filesystem.root]
type = "btrfs"
EOF

fi

cat > "/usr/lib/bootc/install/90-install.toml" << 'EOF'
# Need systemd as the bootloader
[install]
bootloader = "systemd"
EOF

cat > "/usr/lib/dracut/dracut.conf.d/20-bootc-base.conf" << 'EOF'
# Dracut will always fail to set security.selinux xattrs at build time
# https://github.com/dracut-ng/dracut-ng/issues/1561
export DRACUT_NO_XATTR=1

# Enable composefs backend in dracut
add_dracutmodules+=" bootc "
EOF

cat > "/usr/lib/dracut/dracut.conf.d/59-altfiles.conf" << 'EOF'
# https://issues.redhat.com/browse/RHEL-49590
# On image mode systems we use nss-altfiles for passwd and group,
# this makes sure dracut uses them which also fixes kdump writing to NFS.
install_items+=" /usr/lib/passwd /usr/lib/group "
EOF

# Remove more dracut modules to reduce the size of the initramfs
cat > "/usr/lib/dracut/dracut.conf.d/20-omit-modules.conf" << 'EOF'
# FIPS is not supported on Fedora and you need to do your own build anyway
omit_dracutmodules+=" fips fips-crypto-policies "

# Do not include support from booting from a LUN SAS devices
omit_dracutmodules+=" lunmask "

# No LVM support for now
omit_dracutmodules+=" lvm "

# memstrack is for debug and development
omit_dracutmodules+=" memstrack "

# We don't include kernel module keys in the initramfs
omit_dracutmodules+=" modsign "

# NSS is not included in the initramfs
omit_dracutmodules+=" nss-softokn "
EOF

# Include systemd's hwdb
# See: https://github.com/systemd/systemd/issues/40159
# See: https://github.com/systemd/systemd/issues/40485
# cat > "/usr/lib/dracut/dracut.conf.d/20-bootc-composefs.conf" << 'EOF'
# install_items+=" /etc/udev/hwdb.bin "
# EOF

# Prepare folders in /boot
mkdir -p /boot/EFI/Linux

###############################################################################
# Changes for development go here

# secureblue: Remove mask
systemctl unmask sshd.service
# Enable sshd for bcvk
systemctl enable sshd.service

# Disable root password
passwd -d root

# Enable systemd debug shell for the initramfs & final system
cat > "/usr/lib/bootc/kargs.d/10-debug.toml" << 'EOF'
kargs = ["rd.systemd.debug_shell", "systemd.debug_shell"]
EOF

# Mask some systemd units that currently do not work well with some TPMs
# See: https://github.com/systemd/systemd/issues/40159
# See: https://github.com/systemd/systemd/issues/40485
cat > "/usr/lib/bootc/kargs.d/10-tpm2-workaround.toml" << 'EOF'
kargs = [
  "rd.systemd.mask=systemd-tpm2-setup-early.service",
  "systemd.mask=systemd-tpm2-setup-early.service",
  "systemd.mask=systemd-tpm2-setup.service",
  "systemd.mask=systemd-pcrphase.service",
  "systemd.mask=systemd-pcrproduct.service",
]
EOF
###############################################################################
