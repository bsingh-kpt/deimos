#!/bin/bash

# Exit if this has already run for the current user
if [ -f ~/.config/.post-install-done ]; then
	exit 0
fi

# Define apps (ID | Display Name | WMClass)
# Most Flatpaks use the last part of their ID as the WMClass, but some (Brave/Firefox) are unique.
APPS=(
	"app.polychromatic.controller" "Polychromatic" "polychromatic"
	"org.mozilla.firefox" "Firefox" "firefox"
	"org.libreoffice.LibreOffice" "LibreOffice" "libreoffice-startcenter"
	"dev.vencord.Vesktop" "Vesktop (Discord)" "vesktop"
)

total_apps=$((${#APPS[@]} / 3))
current=0
mkdir -p ~/.local/share/applications

(
	for ((i = 0; i < ${#APPS[@]}; i += 3)); do
		id="${APPS[$i]}"
		name="${APPS[$i + 1]}"
		wmclass="${APPS[$i + 2]}"

		current=$((current + 1))
		percent=$((current * 100 / total_apps))

		echo "# Installing $name ($current/$total_apps)..."
		echo "$percent"

		# Install the flatpak
		# flatpak install -y flathub "$id" >/dev/null 2>&1
		flatpak install -y flathub "$id"

		# Copy official desktop file to local override
		# This prevents duplicates and fixes the "broken icon" in Crystal Dock
		SYS_FILE="/var/lib/flatpak/exports/share/applications/$id.desktop"
		LOCAL_FILE="$HOME/.local/share/applications/$id.desktop"

		if [ -f "$SYS_FILE" ]; then
			cp "$SYS_FILE" "$LOCAL_FILE"
			# Append the link that tells the Dock "This window belongs to this icon"
			echo "StartupWMClass=$wmclass" >>"$LOCAL_FILE"
		fi
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
