#!/usr/bin/env bash

sudo pacman -S --noconfirm --needed base-devel xdg-desktop-portal xdg-desktop-portal-hyprland hyprpolkitagent qt5-wayland qt6-wayland bluez bluez-utils wl-clipboard openssh

sudo systemctl daemon-reload

read -p "Do you want to set up Uncomplicated FireWall (ufw) (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	sudo pacman -S --noconfirm --needed ufw
	sudo systemctl enable ufw.service
	sudo systemctl start --now ufw.service
	sudo ufw enable
	sudo ufw allow from 192.168.0.0/24
	sudo ufw allow Deluge
	sudo ufw limit ssh
	sudo ufw default deny

  ;;
  [nN] | [nN][oO]) echo "Omitting firewall setup";;
  * ) echo "invalid option";;
esac

read -p "Do you want to install fonts (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	sudo pacman -S --noconfirm --needed otf-montserrat inter-font ttf-input-nerd

	read -p "Include Japanese font support (yes/no)? " jp_fonts
	case "$jp_fonts" in 
	  [yY] | [yY][eE][sS]) 
		sudo pacman -S --noconfirm --needed ttf-jigmo noto-fonts-cjk
	  ;;
	  [nN] | [nN][oO]) echo "Omitting emojis";;
	  * ) echo "invalid option";;
	esac

	read -p "Do you want to install emojis (yes/no)? " emojis
	case "$emojis" in 
	  [yY] | [yY][eE][sS]) 
		sudo pacman -S --noconfirm --needed noto-fonts-emoji
	  ;;
	  [nN] | [nN][oO]) echo "Omitting emojis";;
	  * ) echo "invalid option";;
	esac

	fc-cache

  ;;
  [nN] | [nN][oO]) echo "Omitting fonts";;
  * ) echo "invalid option";;
esac

if rfkill list bluetooth | grep -q "Soft blocked: yes"; then
  echo "Unblocking Bluetooth..."
  sudo rfkill unblock bluetooth
fi
if ! systemctl is-active --quiet bluetooth; then
	echo "Starting Bluetooth service..."
	sudo systemctl enable bluetooth
	sudo systemctl start bluetooth
	echo "Turning on Bluetooth..."
	sudo bluetoothctl power on
	echo "Bluetooth should now be enabled."
fi

if ! command -v -- paru > /dev/null 2>&1; then
	git clone https://aur.archlinux.org/paru.git
	cd paru
	makepkg -si --noconfirm --needed
	rm -rf paru
fi

aur=paru

"$aur" -S --noconfirm --needed hyprland kitty ffmpeg brightnessctl xdg-user-dirs nwg-look android-file-transfer

# Dev
"$aur" -S --noconfirm --needed neovim git tmux man-pages man-db

# Personal
"$aur" -S --noconfirm --needed vlc vlc-plugins-all

browsers=(zen-browser brave)
for browser in "${browsers[@]}"; do
	if ! command -v -- "$browser" > /dev/null 2>&1; then
		"$aur" -S --noconfirm --needed "$browser"
	fi
done

read -p "Do you want to install default user dirs (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	xdg-user-dirs-update
  ;;
  [nN] | [nN][oO]) echo "no";;
  * ) echo "invalid";;
esac

CURRENT_SHELL=$(basename "$SHELL")
autostart_file_content='if uwsm check may-start >/dev/null 2>&1 && uwsm select; then
	exec uwsm start hyprland-uwsm.desktop
fi'

case "$CURRENT_SHELL" in
	zsh )
		if [ -e "$HOME/.zsh_profile" ]; then
			STARTUP_FILE="$HOME/.zsh_profile"
		fi
	;;
	* )
		if [ ! -e "$HOME/.bash_profile" ]; then
			echo "No ~/.bash_profile nor ~/.bashrc founded. Creating ~/.bash_profile"
			touch "$HOME/.bash_profile"
		fi
		STARTUP_FILE="$HOME/.bash_profile"
	;;
esac

read -p "Do you want to start Hyprland on start (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	sudo pacman -S --noconfirm --needed uwsm libnewt

	if grep -Fxq "$autostart_file_content" "$STARTUP_FILE"; then
		echo "Auto start file content already exists, Omitting..."
	else
		autostart_file_content=$'\n'"$autostart_file_content"$'\n'
		echo "$autostart_file_content" >> "$STARTUP_FILE"
		echo "Added auto start to $STARTUP_FILE"
	fi
	
  ;;
  [nN] | [nN][oO]) echo "Omitting starting hyprland on start up";;
  * ) echo "invalid";;
esac

read -p "Do you want to install Asus Laptop support (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	"$aur" -S --noconfirm --needed asusctl
  ;;
  [nN] | [nN][oO]) echo "Asus laptop support not installed!";;
  * ) echo "Invalid option";;
esac

default_ssh_file="$HOME/.ssh/id_ed25519"
if [ ! -e "$default_ssh_file" ]; then
	read -p "Setup ssh key for github (yes/no)? " choice
	case "$choice" in 
	  [yY] | [yY][eE][sS]) 
			ssh-keygen -t ed25519 -C "s4malve@gmail.com"
			eval "$(ssh-agent -s)"
			ssh-add "$default_ssh_file" 
		;;
	  [nN] | [nN][oO]) echo "Avoiding GitHub ssh setup";;
	  * ) echo "invalid";;
	esac
fi

read -p "Setup passwords (yes/no)? " choice
case "$choice" in 
  [yY] | [yY][eE][sS]) 
	  sudo pacman -S --noconfirm --needed pass github-cli
	  if ! gh auth status | grep -q "Logged in to github.com account s4malve"; then
		  gh auth login
	  fi
	  if ! gh auth status | grep -q "admin:public_key"; then
		  gh auth refresh -h github.com -s admin:public_key
		  gh ssh-key add "$default_ssh_file.pub"
	  fi
	  git clone git@github.com:s4malve/pwd.git "$HOME/.password-store" && echo "Passwords clone successfully on ~/.password-store"
  ;;
  [nN] | [nN][oO]) echo "Avoiding password setup";;
  * ) echo "invalid";;
esac
