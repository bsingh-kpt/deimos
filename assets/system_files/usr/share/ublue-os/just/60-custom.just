# vim: set ft=make :

bsingh-kpt-help:
    #!/usr/bin/bash
    echo "Available commands:"
    echo " - sysupdate-yubisign"
    echo " - setup-fido2-mfa"
    echo " - unmfa-sudo"

# Perform manual system update and sign with Yubikey
sysupdate-yubisign:
    #!/usr/bin/bash
    set -euo pipefail

    /usr/bin/topgrade --config /usr/share/ublue-os/topgrade.toml
    sudo /usr/bin/yubikey-sign-kernel
    echo "Update complete. Please reboot."


# Setup Yubikey FIDO MFA auth for sudo
[group('bsingh-customizations')]
unmfa-sudo:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    if [[ $(id -u) -ne 0 ]]; then
      echo "This command requires root. Run this command with sudo or in a root shell."
      echo "If you have locked yourself out of 'sudo' command, please restore sudo access via Live USB."
      exit 1
    fi
    cp -f /usr/etc/pam.d/sudo /etc/pam.d/sudo
    chown root:root /etc/pam.d/sudo
    chmod 644 /etc/pam.d/sudo
    restorecon /etc/pam.d/sudo
    echo "unmfa-sudo success. sudo pam auth has been restored to system default."

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
    # ANSI Color Codes
    YELLOW='\033[1;33m'
    CYAN='\033[1;36m'
    RED='\033[1;31m'
    NC='\033[0m' # No Color

    BOLD='\033[1m'
    BLINK='\033[5m'

    PREVIOUS_LINE='\033[A'
    CLEAR_LINE='\033[K'

    warn_user() {
        local pammod="$1"
        local pammodU="$(echo -n "$1" | tr a-z A-Z)"
        echo -e "${YELLOW}"
        echo "----------------------------------------------------------------"
        echo -e "  ${BOLD}⚠️  WARNING: PERMANENTLY MODIFYING PAM $pammodU ⚠️${NC}${YELLOW}"
        echo "----------------------------------------------------------------"
        echo -e " You are about to enable Yubikey MFA for all 'sudo' commands."
        echo ""
        echo -e " To prevent lockout, follow these steps exactly:"
        echo ""
        echo -e " ${BOLD}1. PREPARE RECOVERY:${NC}${YELLOW}"
        echo -e "    Open a NEW terminal and run: ${CYAN}sudo -i${NC}${YELLOW}"
        echo "    Keep that root shell open! It is your only way out if this fails."
        echo ""
        echo -e " ${BOLD}2. TEST THE CONFIGURATION:${NC}${YELLOW}"
        echo "    After this script finishes, open a THIRD terminal and run:"
        if [ "$pammod" == "sudo" ]; then
            echo -e "    ${CYAN}sudo -K && sudo whoami${NC}${YELLOW}"
        else
            echo -e "    ${CYAN}pkexec whoami${NC}${YELLOW}"
        fi
        echo "    Confirm it requires your Password AND a Yubikey touch."
        echo ""
        echo -e " ${BOLD}3. EMERGENCY REVERT:${NC}${YELLOW}"
        if [ "$pammod" == "sudo" ]; then
            echo "    If you cannot authenticate, go to the root shell (Step 1) and run:"
            echo -e "    ${CYAN}ujust unmfa-sudo${NC}${YELLOW}"
        else
            echo "    If you cannot authenticate, disable polkit MFA by running in current shell:"
            echo -e "    ${CYAN}ujust setup-fido2-mfa disable-mfa-polkit${NC}${YELLOW}"
        fi
        echo ""
        echo " If all shells are closed and it fails, you must use a Live USB to restore sudo access."
        echo "----------------------------------------------------------------"
        echo -e "${NC}"
        
        read -p "Have you opened a 'sudo -i' shell and are ready to proceed? (y/N): " confirm
        if [[ $confirm != [yY] ]]; then
            echo "Aborting setup."
            exit 1
        fi
    }

    YUBI_U2F_KEYS="/etc/Yubico/u2f_keys"
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-fido2-mfa <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enroll-key' to select Enroll FIDO2 key for $USER"
      echo "  Use 'enroll-addl-key' to select Enroll additional FIDO2 key for $USER"
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
        if [[ -f "$YUBI_U2F_KEYS" ]] && grep -q "^${USER}:" "$YUBI_U2F_KEYS"; then
            echo -e "${RED}Error:${NC} User '$USER' is already enrolled in $YUBI_U2F_KEYS. Aborting..." >&2
            echo -e "TIP 1: Did you mean to register additional Yubikey? Use ${CYAN}enroll-addl-key${NC} option instead."
            echo "TIP 2: To replace existing key, please manually delete user's entry from file '$YUBI_U2F_KEYS' and run this command again."
            exit 1
        fi

        echo "Enrolling key for $USER"
        echo -e "${BOLD}Waiting for YubiKey...${NC}"
        echo -e "${YELLOW}${BLINK}→ Please tap the flashing button on your YubiKey now.${NC}"

        if pamu2fcfg -o pam://bsingh-kpt -i pam://bsingh-kpt > /tmp/u2f_keys_user; then
            # SUCCESS: Move up and overwrite the blinking prompt with a clean success message
            echo -e "${PREVIOUS_LINE}${CLEAR_LINE}${SUCCESS}Key touch detected! Registration complete."
        else
            # FAILURE: Move up and overwrite with the error
            echo -e "${PREVIOUS_LINE}${CLEAR_LINE}No touch detected or command failed."
            exit 1
        fi
        trap 'if [ -f "/tmp/u2f_keys_user" ]; then shred -u "/tmp/u2f_keys_user"; fi' EXIT
        chmod 600 /tmp/u2f_keys_user

        if [[ -f "$YUBI_U2F_KEYS" && -s "$YUBI_U2F_KEYS" ]]; then
            \cp -f $YUBI_U2F_KEYS /tmp/u2f_keys
            # Ensure the file ends in a newline before appending
            sed -i '$a\' "$YUBI_U2F_KEYS" 2>/dev/null || true
        else
            : > /tmp/u2f_keys
        fi
        trap 'if [ -f "/tmp/u2f_keys" ]; then shred -u "/tmp/u2f_keys"; fi' EXIT
        chmod 600 /tmp/u2f_keys

        cat /tmp/u2f_keys_user >> /tmp/u2f_keys
        shred -z /tmp/u2f_keys_user

        sudo mkdir -p /etc/Yubico
        sudo cp -f /tmp/u2f_keys $YUBI_U2F_KEYS
        sudo chown root:root $YUBI_U2F_KEYS
        sudo chmod 644 $YUBI_U2F_KEYS
        shred -z /tmp/u2f_keys

    elif [[ "${OPTION,,}" =~ (^enroll[[:space:]]additional|enroll-addl-key) ]]; then
        if [[ ! -f "$YUBI_U2F_KEYS" ]] || ! grep -qE "^${USER}:" "$YUBI_U2F_KEYS"; then
            echo -e "${RED}Error:${NC} User '$USER' is not enrolled in $YUBI_U2F_KEYS. Aborting..." >&2
            echo -e "TIP: Did you mean to enroll your first key? Use ${CYAN}enroll-key${NC} option instead."
            exit 1
        fi

        grep -E "^${USER}:" "$YUBI_U2F_KEYS" | sed 's/:$//' > /tmp/u2f_keys_user
        trap 'if [ -f "/tmp/u2f_keys_user" ]; then shred -u "/tmp/u2f_keys_user"; fi' EXIT
        chmod 600 /tmp/u2f_keys_user
        sed -i -z 's/\n$//' /tmp/u2f_keys_user

        echo "Enrolling additional key for $USER"
        echo -e "${BOLD}Waiting for YubiKey...${NC}"
        echo -e "${YELLOW}${BLINK}→ Please tap the flashing button on your YubiKey now.${NC}"

        if pamu2fcfg -o pam://bsingh-kpt -i pam://bsingh-kpt -n >> /tmp/u2f_keys_user; then
            # SUCCESS: Move up and overwrite the blinking prompt with a clean success message
            echo -e "${PREVIOUS_LINE}${CLEAR_LINE}${SUCCESS}Key touch detected! Registration complete."
        else
            # FAILURE: Move up and overwrite with the error
            echo -e "${PREVIOUS_LINE}${CLEAR_LINE}No touch detected or command failed."
            return 1
        fi

        grep -vE "^${USER}:" "$YUBI_U2F_KEYS" > /tmp/u2f_keys || : > /tmp/u2f_keys
        trap 'if [ -f "/tmp/u2f_keys" ]; then shred -u "/tmp/u2f_keys"; fi' EXIT

        cat /tmp/u2f_keys_user >> /tmp/u2f_keys
        shred -z /tmp/u2f_keys_user

        sudo cp -f /tmp/u2f_keys $YUBI_U2F_KEYS
        sudo chown root:root $YUBI_U2F_KEYS
        sudo chmod 644 $YUBI_U2F_KEYS
        shred -z /tmp/u2f_keys

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]sudo|enable-mfa-sudo) ]]; then
        warn_user "sudo"
        echo "Enabling MFA for sudo..."
        sudo cp -f /usr/share/bsingh-kpt/pam.d/sudo /etc/pam.d/sudo
        sudo chown root:root /etc/pam.d/sudo
        sudo chmod 644 /etc/pam.d/sudo
        sudo restorecon /etc/pam.d/sudo

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]sudo|disable-mfa-sudo) ]]; then
        echo "Disabling MFA for sudo"
        sudo cp -f /usr/etc/pam.d/sudo /etc/pam.d/sudo
        sudo chown root:root /etc/pam.d/sudo
        sudo chmod 644 /etc/pam.d/sudo
        sudo restorecon /etc/pam.d/sudo

    elif [[ "${OPTION,,}" =~ (^enable[[:space:]]polkit|enable-mfa-polkit) ]]; then
        warn_user "polkit-1"
        echo "Enabling MFA for polkit..."
        sudo cp -f /usr/share/bsingh-kpt/pam.d/polkit-1 /etc/pam.d/polkit-1
        sudo chown root:root /etc/pam.d/polkit-1
        sudo chmod 644 /etc/pam.d/polkit-1
        sudo restorecon /etc/pam.d/polkit-1

    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]polkit|disable-mfa-polkit) ]]; then
        echo "Disabling MFA for polkit"
        sudo rm -f /etc/pam.d/polkit-1
        sudo chown root:root /etc/pam.d/polkit-1
        sudo chmod 644 /etc/pam.d/polkit-1
        sudo restorecon /etc/pam.d/polkit-1
    fi
