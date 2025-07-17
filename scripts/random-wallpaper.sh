#! /usr/bin/env bash

WALLPAPER_DIR="$HOME/.wallpapers/"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
	echo "wallpaper dir not found. Exiting..."
	exit 1
fi


CURRENT_WALL=$(hyprctl hyprpaper listloaded)

# Get a random wallpaper that is not the current one
WALLPAPER=$(find "$WALLPAPER_DIR" -path "$WALLPAPER_DIR/.git" -prune -o -type f ! -name "$(basename "$CURRENT_WALL")" -print | shuf -n 1)

# Apply the selected wallpaper
hyprctl hyprpaper reload eDP-1,"$WALLPAPER"
sleep 1
hyprctl hyprpaper unload unused
