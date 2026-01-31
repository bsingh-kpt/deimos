#!/bin/bash

# Exit if this has already run for the current user
if [ -f ~/.config/.post-install-done ]; then
	exit 0
fi

# Define apps (Display Name | ID)
APPS=(
	"Flatseal" "com.github.tchx84.Flatseal"
	"Firefox" "org.mozilla.firefox"
	"Image Viewer" "org.gnome.Loupe"
	"LibreOffice" "org.libreoffice.LibreOffice"
	"Vesktop (Discord)" "dev.vencord.Vesktop"
	"Podman Desktop" "io.podman_desktop.PodmanDesktop"
	"Calibre" "com.calibre_ebook.calibre"
)

total_apps=$((${#APPS[@]} / 2))
current=0
mkdir -p ~/.local/share/applications

(
	for ((i = 0; i < ${#APPS[@]}; i += 2)); do
		name="${APPS[$i]}"
		id="${APPS[$i + 1]}"

		current=$((current + 1))
		percent=$((current * 100 / total_apps))

		echo "# Installing $name ($current/$total_apps)..."
		echo "$percent"

		# Install the flatpak
		# flatpak install -y flathub "$id" >/dev/null 2>&1
		flatpak install -y flathub "$id"

		# Copy official desktop file to local override for any post install modification
		# SYS_FILE="/var/lib/flatpak/exports/share/applications/$id.desktop"
		# LOCAL_FILE="$HOME/.local/share/applications/$id.desktop"
	done
) | zenity --progress --title="System Setup" --text="Starting installation..." --percentage=0 --auto-close --width=400

# Refresh KDE cache so the new overrides are active immediately
kbuildsycoca6 >/dev/null 2>&1

# Mark as done
touch ~/.config/.post-install-done

# Disable the trigger for future logins
mkdir -p ~/.config/autostart
cat <<EOF >~/.config/autostart/trigger-post-install.desktop
[Desktop Entry]
Type=Application
Name=Initial Software Setup
Hidden=true
EOF

zenity --info --text="Installation Complete! Your software is ready to use." --width=300
