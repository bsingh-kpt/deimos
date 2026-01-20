# vim: set ft=make :

# just script example
_install_appimage_file $APPIMAGE_SRC $filename="":
    #!/usr/bin/bash
    set -eo pipefail
    DOWNLOAD_DIR="{{ cache_directory() }}/ujust/appimages"
    mkdir -p "$DOWNLOAD_DIR"
    trap "rm -rf $DOWNLOAD_DIR" EXIT

    appimage_file="$DOWNLOAD_DIR/${filename:-${APPIMAGE_SRC##*/}}"

    if ! grep -q 'it.mijorus.gearlever' < <(flatpak list --columns application); then
        flatpak install --system -y flathub it.mijorus.gearlever <&-
    fi
    if [[ $APPIMAGE_SRC =~ ^https?:// ]]; then
        echo "Downloading $APPIMAGE_SRC to $appimage_file"
        wget -nv "$APPIMAGE_SRC" -O "$appimage_file" && echo "Download complete"
    else
        cp "$APPIMAGE_SRC" "$appimage_file"
    fi
    chmod +x "$appimage_file"
    echo "Click {{ BOLD }}Unlock{{ NORMAL }} then {{ BLUE + BOLD }}Move to the app menu{{ NORMAL }} and close window to finish installation."
    sleep 3
    LC_ALL=C flatpak run it.mijorus.gearlever "$appimage_file" <&-


# Perform manual system update and sign with Yubikey
manual-update:
    #!/usr/bin/bash
    rpm-ostree upgrade
    sudo /usr/bin/yubikey-sign-kernel
    echo "Update complete. Please reboot."

# Enroll Yubikey FIDO2 PAM keys (pam_u2f)
[group('bsingh-customizations')]
enroll-fido2-keys:
    #!/usr/bin/bash
    set -eo pipefail
    if [ -f /etc/Yubico/u2f_keys ]; then
        echo "/etc/Yubico/u2f_keys exists. Keys already enrolled. Aborting..."
        echo "If you would like to re-enroll new keys, please delete the file."
        exit 1
    fi
    pam 

# Setup Yubikey FIDO MFA auth for sudo
#[group('bsingh-customizations')]
#setup-mfa-sudo: (_setup_fido2_yubikey "sudo")

# Setup Yubikey FIDO MFA auth for sudo
[group('bsingh-customizations')]
setup-fido2-mfa ACTION="":
    #!/usr/bin/bash
    set -eo pipefail
    source /usr/lib/ujust/ujust.sh
    if [[ $(id -u) -eq 0 ]]; then
      echo "Please do not run this command as root"
      exit 1
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-fido2-mfa <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enroll-key' to select Enroll FIDO2 key for $USER"
      echo "  Use 'enroll-add-key' to select Enroll additional FIDO2 key for $USER"
      echo "  Use 'enable-mfa-sudo' to select Enable sudo FIDO2 MFA"
      echo "  Use 'disable-mfa-sudo' to select Disable sudo FIDO2 MFA"
      echo "  Use 'enable-mfa-polkit' to select Enable polkit FIDO2 MFA"
      echo "  Use 'disable-mfa-polkit' to select Disable polkit FIDO2 MFA"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}FIDO2 MFA Setup${normal}"
      echo ""
      OPTION=$(Choose \
        "Enroll FIDO2 key for $USER" \
        "Enroll additional FIDO2 key for $USER" \
        "Enable sudo FIDO2 MFA" \
        "Disable sudo FIDO2 MFA" \
        "Enable polkit FIDO2 MFA" \
        "Disable polkit FIDO2 MFA" \
      )
    fi
    if [[ "${OPTION,,}" =~ (^enroll[[:space:]]fido2|enroll-key) ]]; then
        echo "Enrolling key for $USER"
        if [[ -f "/home/$USER/.config/Yubico/u2f_keys" ]]; then
            echo "Error: /home/$USER/.config/Yubico/u2f_keys file found. Aborting..." >&2
            echo "       Please delete the file to enroll new key" >&2
            exit 1
        fi
        mkdir -p /home/$USER/.config/Yubico
        pamu2fcfg -o pam://bsingh-kpt -i pam://bsingh-kpt > /home/$USER/.config/Yubico/u2f_keys
    elif [[ "${OPTION,,}" =~ (^enroll[[:space:]]additional|enroll-add-key) ]]; then
        echo "Enrolling additional key for $USER"
        if [[ ! -f "/home/$USER/.config/Yubico/u2f_keys" ]]; then
            echo "Error: /home/$USER/.config/Yubico/u2f_keys file not found. Aborting..." >&2
            echo "       Please enroll first key before enrolling additional key" >&2
            exit 1
        fi
        pamu2fcfg -o pam://bsingh-kpt -i pam://bsingh-kpt -n >> /home/$USER/.config/Yubico/u2f_keys
    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]sudo|enable-mfa-sudo) ]]; then
        echo "${yellow}${bold}!!! WARNING !!!${normal}"
        echo "${yellow}This recipe will proceed to ${bold}enable MFA for sudo.${normal}"
        echo "${yellow}Enabling MFA for sudo or polkit will then require FIDO2 key (Yubikey) be present.${normal}"
        echo "${yellow}This can ${bold}lock sudo command.${normal}${yellow} You'll need sudo or live USB boot to undo the changes.${normal}"
        echo ""
        echo "Are you sure you want to continue?"
        OPTION=$(Choose "Proceed" "Quit")
        case "$OPTION" in
          Proceed|proceed)
            echo "Enabling MFA for sudo..."
            sudo cp -f /usr/share/bsingh-kpt/pam.d/sudo /etc/pam.d/sudo
            ;;
          *)
            echo "Aborting..."
            exit 0
            ;;
        esac
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]sudo|disable-mfa-sudo) ]]; then
        echo "Disabling MFA for sudo"
        sudo cp -f /usr/etc/pam.d/sudo /etc/pam.d/sudo
    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]polkit|enable-mfa-polkit) ]]; then
        echo "${yellow}${bold}!!! WARNING !!!${normal}"
        echo "${yellow}This recipe will proceed to ${bold}enable MFA for polkit (GUI prompts).${normal}"
        echo "${yellow}Enabling MFA for sudo or polkit will then require FIDO2 key (Yubikey) be present.${normal}"
        echo "${yellow}This can cause ${bold}failed polkit password prompts.${normal}${yellow} You'll need live USB boot to undo the changes.${normal}"
        echo ""
        echo "Are you sure you want to continue?"
        OPTION=$(Choose "Proceed" "Quit")
        case "$OPTION" in
          Proceed|proceed)
            echo "Enabling MFA for polkit..."
            sudo cp -f /usr/share/bsingh-kpt/pam.d/polkit-1 /etc/pam.d/polkit-1
            ;;
          *)
            echo "Aborting..."
            exit 0
            ;;
        esac
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]polkit|disable-mfa-polkit) ]]; then
        echo "Disabling MFA for polkit"
        sudo rm -f /etc/pam.d/polkit-1
    fi
