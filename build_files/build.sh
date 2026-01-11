#!/bin/bash

set -ouex pipefail

### INSTALL PACKAGES SECTION - START ###
# Enable COPR
dnf5 -y copr enable ublue-os/staging
dnf5 install -y \
	yubikey-manager \
	opensc \
	libfido2 \
	pam-u2f pamu2fcfg \
	sbsigntools \
	crystal-dock

# Disable COPR
dnf5 -y copr disable ublue-os/staging

## Non dnf installations
# Install starship prompt binary
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir /usr/bin/ -y

### INSTALL PACKAGES SECTION - END ###

### SYSTEM CONFIGURATION SECTION - START ###
# Configure Yubikey for Sudo (PAM)
sed -i '3i auth       required     pam_u2f.so cue' /etc/pam.d/sudo

## System services
systemctl enable podman.socket
systemctl disable ublue-update.timer
systemctl mask ublue-update.service

## Deploy KDE Layouts & Widgets
mkdir -p /etc/skel/.config
# Reference /ctx/ because that's where the bind mount is
cp /ctx/config/starship.toml /etc/skel/.config/starship.toml
cp /ctx/config/plasmashellrc /etc/skel/.config/plasmashellrc
cp /ctx/config/appletrc /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc

# Deploy Widgets
mkdir -p /usr/share/plasma/plasmoids
cp -r /ctx/widgets/KdeControlStation /usr/share/plasma/plasmoids/
cp -r /ctx/widgets/luisbocanegra.panel.colorizer /usr/share/plasma/plasmoids/
cp -r /ctx/widgets/org.kde.windowtitle /usr/share/plasma/plasmoids/
cp -r /ctx/widgets/zayron.chaac.weather /usr/share/plasma/plasmoids/
cp -r /ctx/widgets/zayron.simple.separator /usr/share/plasma/plasmoids/

## Install Secure Boot Signing Hook
cp /ctx/scripts/yubikey-sign-kernel /usr/bin/yubikey-sign-kernel
chmod +x /usr/bin/yubikey-sign-kernel

## Create 'just' command for Manual Updates
mkdir -p /usr/share/ublue-os/just
cat <<'EOF' >>/usr/share/ublue-os/just/60-custom.just
# Perform manual system update and sign with Yubikey
manual-update:
    rpm-ostree upgrade
    sudo /usr/bin/yubikey-sign-kernel
    echo "Update complete. Please reboot."
EOF

## bashrc modifications
# Fixes flatpak apps KDE icons in crystal-dock
cat << 'EOF' >> /etc/profile.d/flatpak-exports.sh
export XDG_DATA_DIRS=$HOME/.local/share/applications:$XDG_DATA_DIRS
EOF
# Activate starship prompt
# Make sure this is the lasts modidfication to bashrc
cat <<'EOF' >>/etc/skel/.bashrc

if [[ $- == *i* ]]
then
    fastfetch
fi
eval "$(starship init bash)"
EOF

### SYSTEM CONF SECTION - END ###

### USER CONF SECTION - START ###
## Crystal dock startup
mkdir -p /etc/xdg/autostart
cat <<'EOF' >>/etc/xdg/autostart/crystal-dock.desktop
[Desktop Entry]
Name=Crystal Dock
Comment=Pro-animation dock for Linux
Exec=crystal-dock
Terminal=false
Type=Application
Icon=crystal-dock
Categories=System;
X-KDE-autostart-after=panel
EOF
## bashrc modifications
### SYSTEM CONF SECTION - END ###

### POST INSTALL SECTION - START ###
# Post install software setup
cp -f /ctx/scripts/post-install-setup-flatpak.sh /usr/bin/post-install-setup
chmod +x /usr/bin/post-install-setup
cat <<'EOF' >/etc/xdg/autostart/trigger-post-install.desktop
[Desktop Entry]
Name=Initial Software Setup
Exec=/usr/bin/post-install-setup
Type=Application
Terminal=false
X-KDE-autostart-after=panel
EOF
### POST INSTALL SECTION - END ###

### DELL test pc related only. REMOVE AFTER TESTING ### START
# Blacklist TPM modules to stop the 45s timeouts
printf "blacklist tpm_tis\nblacklist tpm_crb\nblacklist tpm\n" >/etc/modprobe.d/blacklist-tpm.conf
# Force dracut to omit TPM modules in the initramfs
mkdir -p /usr/lib/dracut/dracut.conf.d &&
	echo 'omit_dracutmodules+=" tpm2-tss "' >/usr/lib/dracut/dracut.conf.d/omit-tpm.conf
systemctl mask dev-tpmrm0.device tpm2.target
# Install xrdp
dnf5 install -y xrdp
systemctl enable xrdp
cat <<'EOF' >>/usr/lib/firewalld/zones/public.xml
<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Public</short>
  <description>For use in public areas.</description>
  <service name="ssh"/>
  <service name="dhcpv6-client"/>
  <port port="3389" protocol="tcp"/>
</zone>
EOF
### DELL test pc related only. REMOVE AFTER TESTING ### END
