#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./restore-kde-rice.sh <path-to-backup-tar-gz>"
    exit 1
fi

ARCHIVE_FILE="$1"
EXTRACT_DIR="temp_kde_restore"

echo "[+] Extracting archive: $ARCHIVE_FILE..."
mkdir -p "$EXTRACT_DIR"
tar -xzvf "$ARCHIVE_FILE" -C "$EXTRACT_DIR" --strip-components=1

echo "[+] Restoring User Configurations (~/.config)..."
mkdir -p ~/.config
cp -r "$EXTRACT_DIR"/user_config/* ~/.config/ 2>/dev/null || true

echo "[+] Restoring User Assets (~/.local/share)..."
mkdir -p ~/.local/share
cp -r "$EXTRACT_DIR"/user_local_share/* ~/.local/share/ 2>/dev/null || true

echo "[+] Restoring SDDM Configurations & Themes (sudo required)..."
if [ -d "$EXTRACT_DIR/sddm_etc" ]; then
    sudo cp -r "$EXTRACT_DIR"/sddm_etc/* /etc/ 2>/dev/null || true
fi
if [ -d "$EXTRACT_DIR/sddm_usr/themes" ]; then
    sudo cp -r "$EXTRACT_DIR"/sddm_usr/themes/* /usr/share/sddm/themes/ 2>/dev/null || true
fi

echo "[+] Cleaning up temporary files..."
rm -rf "$EXTRACT_DIR"

echo "[+] Restarting Plasma Shell..."
plasmashell --replace &>/dev/null &

echo "[SUCCESS] Restoration completed! Please log out and back in for full effect."
