#!/bin/bash

set -ouex pipefail

### Definitions ###
YUBICO_AUTHENTICATOR_VERSION=7.3.0
TABBY_VERSION=1.0.229
PROTONMAL_VERSION=1.12.0

### Image metadata and verification
cp /ctx/cosign.pub /etc/pki/containers/bsingh-kpt.pub
cat <<'EOF' >/etc/containers/registries.d/bsingh-kpt.yaml
docker:
  ghcr.io/bsingh-kpt:
    sigstoreSigned:
      keyPath: /etc/pki/containers/bsingh-kpt.pub
EOF

IMAGEINFO_FEDORA_VERSION=$(grep '"fedora-version":' /usr/share/ublue-os/image-info.json | cut -d '"' -f 4)
IMAGEINFO_VERSION=$(grep '"version":' /usr/share/ublue-os/image-info.json | cut -d '"' -f 4)
IMAGEINFO_VERSION_PRETTY=$(grep '"version-pretty":' /usr/share/ublue-os/image-info.json | cut -d '"' -f 4)
IMAGEINFO_COMMIT_ID=${IMAGE_COMMIT_ID:-unknown}
case "${GITHUB_REF_NAME}" in
"main")
	IMAGEINFO_IMAGE_TAG="latest"
	;;
"stable")
	IMAGEINFO_IMAGE_TAG="stable"
	;;
*)
	# Fallback for feature branches or empty variables
	IMAGEINFO_IMAGE_TAG="${GITHUB_REF_NAME:-dirty}"
	;;
esac
cat <<EOF >/usr/share/ublue-os/image-info.json
{
  "image-name": "bazziteos",
  "image-vendor": "bsingh-kpt",
  "image-ref": "ostree-image-signed:docker://ghcr.io/bsingh-kpt/bazziteos",
  "image-tag": "$IMAGEINFO_IMAGE_TAG",
  "image-branch": "main",
  "image-commit-id": "$IMAGEINFO_COMMIT_ID",
  "base-image-name": "bazzite-nvidia",
  "fedora-version": "$IMAGEINFO_FEDORA_VERSION",
  "version": "$IMAGEINFO_VERSION",
  "version-pretty": "$IMAGEINFO_VERSION_PRETTY"
}
EOF
###

### INSTALL PACKAGES SECTION - START ###
# Enable COPR
# dnf5 -y copr enable ublue-os/staging
curl -Lo /etc/yum.repos.d/hardware:razer.repo https://openrazer.github.io/hardware:razer.repo

# Standard -dx tools minus the handheld overhead
dnf5 install -y \
	libcgroup \
	docker-ce docker-ce-cli \
	docker-compose docker-compose-plugin docker-buildx-plugin \
	containerd.io \
	podman-docker podman-tui podman-machine \
	git-delta \
	neovim \
	ckb-next polychromatic \
	openrazer-meta openrazer-daemon \
	crystal-dock

# Additional SW
dnf5 install -y \
	yubikey-manager yubico-piv-tool pam_yubico \
	yubikey-manager-qt yubikey-personalization-gui \
	opensc \
	libfido2 \
	pam-u2f pamu2fcfg \
	sbsigntools

dnf5 install -y \
	vlc

# Instal VS Code
wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-rpm-x64" -O /tmp/vscode-latest.rpm
dnf5 install -y /tmp/vscode-latest.rpm
rm -f /tmp/vscode-latest.rpm

# Install Tabby
wget https://github.com/Eugeny/tabby/releases/download/v$TABBY_VERSION/tabby-$TABBY_VERSION-linux-x64.rpm -O /tmp/tabby-$TABBY_VERSION-linux-x64.rpm
dnf5 install -y /tmp/tabby-$TABBY_VERSION-linux-x64.rpm
rm -f /tmp/tabby-$TABBY_VERSION-linux-x64.rpm

# Install ProtonMail
wget https://proton.me/download/mail/linux/$PROTONMAL_VERSION/ProtonMail-desktop-beta.rpm -O /tmp/ProtonMail-desktop-beta.rpm
dnf5 install -y /tmp/ProtonMail-desktop-beta.rpm
rm -f /tmp/ProtonMail-desktop-beta.rpm

# Disable COPR
# dnf5 -y copr disable ublue-os/staging

## Non dnf installations
# Install Yubico Authenticator
wget https://developers.yubico.com/yubioath-flutter/Releases/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux.tar.gz -O /tmp/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux.tar.gz
tar -xvf /tmp/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux.tar.gz -C /opt/
rm -f /tmp/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux.tar.gz
sed -e "s|@EXEC_PATH|/opt/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux|g" \
	<"/opt/yubico-authenticator-$YUBICO_AUTHENTICATOR_VERSION-linux/linux_support/com.yubico.yubioath.desktop" \
	>"/usr/share/applications/com.yubico.yubioath.desktop"
# Install Starship
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
cp -r /ctx/config/crystal-dock-2 /etc/skel/.crystal-dock-2

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
cat <<'EOF' >>/etc/skel/.bashrc
export XDG_DATA_DIRS="${HOME}/.local/share:$XDG_DATA_DIRS"
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
cat <<'EOF' >/etc/xdg/autostart/crystal-dock.desktop
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
# # Blacklist TPM modules to stop the 45s timeouts
# printf "blacklist tpm_tis\nblacklist tpm_crb\nblacklist tpm\n" >/etc/modprobe.d/blacklist-tpm.conf
# # Force dracut to omit TPM modules in the initramfs
# mkdir -p /usr/lib/dracut/dracut.conf.d &&
# 	echo 'omit_dracutmodules+=" tpm2-tss "' >/usr/lib/dracut/dracut.conf.d/omit-tpm.conf
# systemctl mask dev-tpmrm0.device tpm2.target
# # Install xrdp
# dnf5 install -y xrdp
# systemctl enable xrdp
# cat <<'EOF' >>/usr/lib/firewalld/zones/public.xml
# <?xml version="1.0" encoding="utf-8"?>
# <zone>
#   <short>Public</short>
#   <description>For use in public areas.</description>
#   <service name="ssh"/>
#   <service name="dhcpv6-client"/>
#   <port port="3389" protocol="tcp"/>
# </zone>
# EOF
### DELL test pc related only. REMOVE AFTER TESTING ### END
