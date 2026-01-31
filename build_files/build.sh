#!/bin/bash

set -xeuo pipefail

### Definitions ###

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
	IMAGEINFO_IMAGE_BRANCH="main"
	;;
"stable")
	IMAGEINFO_IMAGE_TAG="stable"
	IMAGEINFO_IMAGE_BRANCH="stable"
	;;
*)
	# Fallback for feature branches or empty variables
	IMAGEINFO_IMAGE_TAG="${GITHUB_REF_NAME:-dirty}"
	IMAGEINFO_IMAGE_BRANCH="${GITHUB_REF_NAME}"
	;;
esac
cat <<EOF >/usr/share/ublue-os/image-info.json
{
  "image-name": "bazziteos",
  "image-vendor": "bsingh-kpt",
  "image-ref": "ostree-image-signed:docker://ghcr.io/bsingh-kpt/bazziteos",
  "image-tag": "$IMAGEINFO_IMAGE_TAG",
  "image-branch": "$IMAGEINFO_IMAGE_BRANCH",
  "image-commit-id": "$IMAGEINFO_COMMIT_ID",
  "base-image-name": "bazzite-nvidia-open",
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
curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo

# Standard -dx tools minus the handheld overhead
dnf5 install -y \
	systemd-ukify \
	libcgroup \
	docker-compose \
	podman podman-docker podman-tui podman-machine \
	git-delta \
	kcalc \
	ckb-next polychromatic \
	openrazer-meta openrazer-daemon \
	brave-browser \
	keepassxc \
	yubikey-manager yubico-piv-tool pam_yubico \
	yubikey-manager-qt yubikey-personalization-gui \
	opensc \
	libfido2 \
	pam-u2f pamu2fcfg \
	sbsigntools \
	vlc

### INSTALL PACKAGES SECTION - END ###

### Install customizations
bash /ctx/scripts/install-customizations.sh "/ctx"

# Install Secure Boot Signing Hook
cp /ctx/assets/scripts/yubikey-sign-kernel /usr/bin/yubikey-sign-kernel
chmod +x /usr/bin/yubikey-sign-kernel

# Install 'just' script for custom commands
mkdir -p /usr/share/ublue-os/just
cp -f /ctx/assets/system_files/usr/share/ublue-os/just/60-custom.just /usr/share/ublue-os/just/60-custom.just

# Install share/bsingh-kpt data to /usr/share
cp -r /ctx/assets/system_files/usr/share/bsingh-kpt /usr/share/

### SYSTEM CONFIGURATION SECTION - START ###
## System services
systemctl enable podman.socket
systemctl mask ublue-update.service

# KDE UI configurations
mkdir -p /etc/skel/.config
cp /ctx/assets/config/starship.toml /etc/skel/.config/starship.toml
cp /ctx/assets/config/plasmashellrc /etc/skel/.config/plasmashellrc
cp /ctx/assets/config/appletsrc /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
cp /ctx/assets/config/krunnerrc /etc/skel/.config/krunnerrc
cp /ctx/assets/config/kdeglobals /etc/skel/.config/kdeglobals
# Terminal config
mkdir -p /etc/skel/.config/dconf
cp /ctx/assets/config/dconf_user /etc/skel/.config/dconf/user

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
## Add user conf here
## bashrc modifications
### USER CONF SECTION - END ###

### POST INSTALL SECTION - START ###
# Post install software setup
cp -f /ctx/assets/scripts/post-install-setup-flatpak.sh /usr/bin/post-install-setup
chmod +x /usr/bin/post-install-setup
cat <<'EOF' >/etc/xdg/autostart/trigger-post-install.desktop
[Desktop Entry]
Name=Initial Software Setup
Exec=sleep 10 && /usr/bin/post-install-setup
Type=Application
Terminal=false
X-KDE-autostart-after=panel
EOF
### POST INSTALL SECTION - END ###
