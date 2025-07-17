#!/usr/bin/env bash

set -euo pipefail

# --- Configuration Variables ---
readonly PKG_INSTALL_FLAGS="--noconfirm --needed"

readonly ARCH_PACKAGES="base-devel xdg-desktop-portal xdg-desktop-portal-hyprland hyprpolkitagent qt5-wayland qt6-wayland bluez bluez-utils wl-clipboard openssh"
readonly FONT_PACKAGES="otf-montserrat inter-font ttf-input-nerd"
readonly JP_FONT_PACKAGES="ttf-jigmo noto-fonts-cjk"
readonly EMOJI_FONT_PACKAGES="noto-fonts-emoji"
readonly HYPRLAND_AUR_PACKAGES="hyprland kitty ffmpeg brightnessctl xdg-user-dirs nwg-look android-file-transfer"
readonly DEV_AUR_PACKAGES="neovim git tmux man-pages man-db"
readonly PERSONAL_AUR_PACKAGES="vlc vlc-plugins-all"
readonly UWSM_PACKAGES="uwsm libnewt"
readonly ASUS_PACKAGES="asusctl"
readonly PASSWORD_PACKAGES="pass github-cli"

readonly BROWSERS=(zen-browser brave)

readonly SSH_EMAIL="s4malve@gmail.com"

readonly DEFAULT_SSH_FILE="$HOME/.ssh/id_ed25519"

# --- Helper Functions ---

prompt_for_yes_no() {
    local prompt_msg="$1"
    local default_choice="${2:-no}" # Default to 'no' if not provided
    local choice_lower

    while true; do
        read -rp "$prompt_msg ($default_choice)? " choice
        choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]') # Convert to lowercase

        case "$choice_lower" in
            y|yes) return 0 ;; # Success (yes)
            n|no) return 1 ;;  # Failure (no)
            "")
                if [[ "$default_choice" == "yes" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *) echo "Invalid option. Please enter 'yes' or 'no'." ;;
        esac
    done
}

install_base_packages() {
    echo ""
    echo "--- Installing base system packages ---"
    sudo pacman -S ${PKG_INSTALL_FLAGS} ${ARCH_PACKAGES}
    sudo systemctl daemon-reload || echo "Daemon reload failed, continuing..."
}

setup_ufw() {
    echo "--- Setting up Uncomplicated Firewall (UFW) ---"
    if prompt_for_yes_no "Do you want to set up UFW"; then
        sudo pacman -S ${PKG_INSTALL_FLAGS} ufw
        echo "Enabling and configuring UFW..."
        sudo systemctl enable ufw.service
        sudo systemctl start --now ufw.service
        sudo ufw enable || { echo "Failed to enable UFW." >&2; return 1; }
        sudo ufw default deny
        sudo ufw allow from 192.168.0.0/24 comment 'Allow LAN access'
        sudo ufw allow 6881/tcp comment 'Allow Deluge TCP' # Explicit port
        sudo ufw allow 6881/udp comment 'Allow Deluge UDP'
        sudo ufw limit ssh comment 'Limit SSH access'
        echo "UFW setup complete. Current status:"
        sudo ufw status verbose
    else
        echo "Omitting firewall setup."
    fi
}

install_fonts() {
    echo "--- Installing Fonts ---"
    if prompt_for_yes_no "Do you want to install fonts"; then
        sudo pacman -S ${PKG_INSTALL_FLAGS} ${FONT_PACKAGES}

        if prompt_for_yes_no "Include Japanese font support"; then
            sudo pacman -S ${PKG_INSTALL_FLAGS} ${JP_FONT_PACKAGES}
        else
            echo "Omitting Japanese font support."
        fi

        if prompt_for_yes_no "Do you want to install emojis"; then
            sudo pacman -S ${PKG_INSTALL_FLAGS} ${EMOJI_FONT_PACKAGES}
        else
            echo "Omitting emojis."
        fi
        echo "Updating font cache..."
        fc-cache -fv || echo "Failed to update font cache." >&2
        echo "Font installation complete."
    else
        echo "Omitting font installation."
    fi
}

setup_bluetooth() {
    echo "--- Setting up Bluetooth ---"
    if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
        echo "Unblocking Bluetooth..."
        sudo rfkill unblock bluetooth || echo "Failed to unblock Bluetooth." >&2
    fi

    if ! systemctl is-active --quiet bluetooth.service; then
        echo "Starting and enabling Bluetooth service..."
        sudo systemctl enable bluetooth.service || { echo "Failed to enable Bluetooth service." >&2; return 1; }
        sudo systemctl start bluetooth.service || { echo "Failed to start Bluetooth service." >&2; return 1; }
        echo "Bluetooth service enabled and started."
    else
        echo "Bluetooth service is already active."
    fi

    if bluetoothctl show | grep -q "Powered: no"; then
        echo "Turning on Bluetooth..."
        sudo bluetoothctl power on || echo "Failed to turn on Bluetooth." >&2
        echo "Bluetooth should now be enabled."
    else
        echo "Bluetooth is already powered on."
    fi
}

install_paru() {
    echo "--- Installing Paru (AUR Helper) ---"
    if command -v -- paru >/dev/null 2>&1; then
        echo "Paru is already installed."
        return 0
    fi

    echo "Paru not found. Cloning and building paru from AUR."
    local temp_dir
    temp_dir=$(mktemp -d) || { echo "Failed to create temporary directory." >&2; return 1; }

    if ! git clone https://aur.archlinux.org/paru.git "$temp_dir"; then
        echo "Failed to clone paru repository." >&2
        rm -rf "$temp_dir"
        return 1
    fi

    (
        cd "$temp_dir" || { echo "Failed to change directory to $temp_dir." >&2; return 1; }
        if ! makepkg -si --noconfirm; then
            echo "Failed to build and install paru." >&2
            return 1
        fi
    )
    rm -rf "$temp_dir"
    echo "Paru installed successfully."
    return 0
}

install_aur_packages() {
    aur="paru"
    echo "--- Installing AUR packages ---"
    "$aur" -S ${PKG_INSTALL_FLAGS} ${HYPRLAND_AUR_PACKAGES}
    "$aur" -S ${PKG_INSTALL_FLAGS} ${DEV_AUR_PACKAGES}
    "$aur" -S ${PKG_INSTALL_FLAGS} ${PERSONAL_AUR_PACKAGES}

    echo "Installing browsers..."
    for browser in "${BROWSERS[@]}"; do
        if ! command -v -- "$browser" >/dev/null 2>&1; then
            "$aur" -S ${PKG_INSTALL_FLAGS} "$browser"
        else
            echo "$browser is already installed."
        fi
    done
}

setup_xdg_user_dirs() {
    echo "--- Setting up XDG User Directories ---"
    if prompt_for_yes_no "Do you want to install default user dirs"; then
        echo "Updating XDG user directories..."
        xdg-user-dirs-update || echo "Failed to update XDG user directories." >&2
        echo "XDG user directories updated."
    else
        echo "Omitting XDG user directory setup."
    fi
}

setup_hyprland_autostart() {
    echo "--- Configuring Hyprland Autostart with UWSM ---"
    if ! prompt_for_yes_no "Do you want to start Hyprland on login"; then
        echo "Omitting starting Hyprland on startup."
        return 0
    fi

    sudo pacman -S ${PKG_INSTALL_FLAGS} ${UWSM_PACKAGES}

    local current_shell_name=$(basename "$SHELL")
    local startup_file=""

    case "$current_shell_name" in
        zsh)
            startup_file="$HOME/.zprofile" # More common for login shells with zsh
            if [[ ! -e "$startup_file" ]]; then
                echo "No ~/.zprofile found. Creating it."
                touch "$startup_file"
            fi
            ;;
        bash)
            startup_file="$HOME/.bash_profile"
            if [[ ! -e "$startup_file" ]]; then
                echo "No ~/.bash_profile found. Creating it."
                touch "$startup_file"
            fi
            ;;
        *)
            echo "Warning: Unsupported shell '$current_shell_name'. Cannot configure autostart." >&2
            return 1
            ;;
    esac

    local autostart_content='if uwsm check may-start; then
    exec uwsm start hyprland-uwsm.desktop
fi'

    if grep -Fxq "$autostart_content" "$startup_file"; then
        echo "Autostart content for Hyprland already exists in $startup_file. Omitting..."
    else
        echo -e "\n$autostart_content\n" >> "$startup_file" || { echo "Failed to append autostart content to $startup_file." >&2; return 1; }
        echo "Added Hyprland autostart to $startup_file."
    fi
}

setup_asus_support() {
    echo "--- Setting up Asus Laptop Support ---"
    if prompt_for_yes_no "Do you want to install Asus Laptop support"; then
        "$aur" -S ${PKG_INSTALL_FLAGS} ${ASUS_PACKAGES}
        echo "Asus laptop support installed."
    else
        echo "Asus laptop support not installed."
    fi
}

setup_ssh_key() {
    echo "--- Setting up SSH Key for GitHub ---"
    if [[ -e "$DEFAULT_SSH_FILE" ]]; then
        echo "SSH key already exists at $DEFAULT_SSH_FILE. Skipping generation."
        return 0
    fi

    if prompt_for_yes_no "Setup ssh key for GitHub"; then
        echo "Generating new SSH key..."
        if ! ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$DEFAULT_SSH_FILE" -N ""; then # -N "" for no passphrase
            echo "Failed to generate SSH key." >&2
            return 1
        fi
        eval "$(ssh-agent -s)" || { echo "Failed to start SSH agent." >&2; return 1; }
        ssh-add "$DEFAULT_SSH_FILE" || { echo "Failed to add SSH key to agent." >&2; return 1; }
        echo "SSH key generated and added to agent."
    else
        echo "Avoiding GitHub SSH key setup."
    fi
}

setup_passwords() {
    echo "--- Setting up Password Store ---"
    if ! prompt_for_yes_no "Setup password store"; then
        echo "Avoiding password store setup."
        return 0
    fi

    sudo pacman -S ${PKG_INSTALL_FLAGS} ${PASSWORD_PACKAGES}

    echo "Checking GitHub CLI authentication status..."
    if ! gh auth status &>/dev/null || ! gh auth status | grep -q "Logged in to github.com account s4malve"; then
        echo "Logging into GitHub CLI..."
        if ! gh auth login; then
            echo "GitHub CLI login failed." >&2
            return 1
        fi
    else
        echo "Already logged in to GitHub."
    fi

    if ! gh auth status | grep -q "admin:public_key"; then
        echo "Refreshing GitHub CLI permissions for public key management..."
        if ! gh auth refresh -h github.com -s admin:public_key; then
            echo "Failed to refresh GitHub CLI permissions." >&2
            return 1
        fi
    fi

    if [[ ! -e "$DEFAULT_SSH_FILE.pub" ]]; then
        echo "Error: Public SSH key not found at $DEFAULT_SSH_FILE.pub. Cannot add to GitHub." >&2
        return 1
    fi

    echo "Adding SSH public key to GitHub..."
    if ! gh ssh-key add "$DEFAULT_SSH_FILE.pub"; then
        echo "Failed to add SSH key to GitHub. It might already exist." # This command can fail if key is already there
    fi

    if [[ ! -d "$HOME/.password-store" ]]; then
        echo "Cloning password store from GitHub..."
        if ! git clone git@github.com:s4malve/pwd.git "$HOME/.password-store"; then
            echo "Failed to clone password store." >&2
            return 1
        fi
        echo "Passwords cloned successfully to ~/.password-store."
    else
        echo "Password store already exists at ~/.password-store. Skipping clone."
    fi
}

setup_dotfiles() {
    printf "\n--- Setting up dotfiles ---\n"
    if ! prompt_for_yes_no "Setup dotfiles"; then
        echo "Avoiding dotfiles setup."
        return 0
    fi
    
    sudo pacman -S ${PKG_INSTALL_FLAGS} stow

    printf "\n--- DANGER ---\nThe following operation will delete the following files:"
    stow_config="--target=~"
    stow -n -v .
    if ! prompt_for_yes_no "Do you want to delete conflict files"; then
        echo "Exiting dofiles setup, none of the files where edited or deleted."
        return 0
    fi

}

setup_wallpapers() {
    printf "\n--- Setting up wallpapers ---\n"
    if ! prompt_for_yes_no "Setup wallpapers"; then
        echo "Avoiding wallpapers setup."
        return 0
    fi
    target_dir="/usr/local/bin"
    wallpaper_folder="$HOME/.wallpapers"
    SCRIPTS_FOLDER="scripts"
    random_wallpaper_script="random-wallpaper.sh"
    if [[ ! -d "$wallpaper_folder" ]]; then
	git clone git@github.com:s4malve/.wallpapers.git "$wallpaper_folder"
    fi

    sudo pacman -S ${PKG_INSTALL_FLAGS} hyprpaper
    systemctl --user enable --now hyprpaper


    stow --target="$HOME/.config/" -S hyprpaper
    sudo stow --target="$target_dir" -S "$SCRIPTS_FOLDER"
    sudo chmod +x "$target_dir/$random_wallpaper_script"
    "$random_wallpaper_script"
}

setup_status_bar() {
    printf "\n--- Setting up status bar ---\n"
    if ! prompt_for_yes_no "Setup status bar"; then
        echo "Avoiding status bar setup."
        return 0
    fi
    sudo pacman -S ${PKG_INSTALL_FLAGS} waybar
    stow --target="$HOME/.config/" -S waybar
    systemctl --user enable --now waybar.service
}

aur_install() {
    "$aur" -S ${PKG_INSTALL_FLAGS} ${@}
}

setup_desktop_shell() {
    printf "\n--- Setting up Desktop Shell ---\n"
    if ! prompt_for_yes_no "Setup desktop shell"; then
        echo "Avoiding desktop shell setup."
        return 0
    fi
    aur_install quickshell-git

}

main() {
    echo "Starting Hyprland Arch Linux Post-Install Script..."

    install_base_packages
    setup_ufw
    install_fonts
    setup_bluetooth
    install_paru # Ensure paru is installed before attempting to install AUR packages
    install_aur_packages
    setup_xdg_user_dirs
    setup_hyprland_autostart
    setup_asus_support
    setup_ssh_key
    setup_passwords
    # setup_dotfiles
    setup_wallpapers
    setup_status_bar
    setup_desktop_shell

    echo "Script execution complete!"
    echo "Please consider rebooting your system for all changes to take effect."
}

main
