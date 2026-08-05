#!/bin/bash
set -e

# Create a unique backup directory name with a timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="kde_rice_backup_${TIMESTAMP}"
BACKUP_DIR="$HOME/${BACKUP_NAME}"

echo "[+] Creating temporary backup directory..."
mkdir -p "$BACKUP_DIR/user_config" "$BACKUP_DIR/user_local_share" "$BACKUP_DIR/sddm_etc" "$BACKUP_DIR/sddm_usr"

echo "[+] Backing up Power Management, Sleep & Screen Profiles..."
cp ~/.config/powermanagementprofilesrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kscreenlockerrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp -r ~/.config/kscreen/ "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Panels, Widgets, Shortcuts & Desktop Layouts..."
cp ~/.config/plasmashellrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/plasmarc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kglobalshortcutsrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/khotkeysrc "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Themes, Window Rules, Colors & Fonts..."
cp ~/.config/kdeglobals "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kwinrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kwinrulesrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/ksplashrc "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Custom Installed Assets (Widgets, Icons, Aurorae Themes, Wallpapers)..."
cp -r ~/.local/share/plasma/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/icons/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/themes/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/wallpapers/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/aurorae/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true

echo "[+] Backing up SDDM Configuration & System Themes (Requires sudo)..."
if [ -d /etc/sddm.conf.d ]; then
    sudo cp -r /etc/sddm.conf.d/ "$BACKUP_DIR/sddm_etc/" 2>/dev/null || true
fi
if [ -f /etc/sddm.conf ]; then
    sudo cp /etc/sddm.conf "$BACKUP_DIR/sddm_etc/" 2>/dev/null || true
fi
if [ -d /usr/share/sddm/themes ]; then
    sudo cp -r /usr/share/sddm/themes/ "$BACKUP_DIR/sddm_usr/" 2>/dev/null || true
fi

# Fix permissions on temporary directory so tar doesn't run into root-owned file issues
sudo chown -R "$USER:$USER" "$BACKUP_DIR"

echo "[+] Archiving backup files into ${BACKUP_NAME}.tar.gz..."
tar -czvf "$HOME/${BACKUP_NAME}.tar.gz" -C "$HOME" "$BACKUP_NAME"
rm -rf "$BACKUP_DIR"

echo "[SUCCESS] Backup complete! Saved as: $HOME/${BACKUP_NAME}.tar.gz"
