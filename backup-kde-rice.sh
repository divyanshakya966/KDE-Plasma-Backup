#!/bin/bash
set -e

# Define timestamp and backup directory structure
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="kde_rice_backup_${TIMESTAMP}"
BACKUP_DIR="$HOME/${BACKUP_NAME}"

echo "[+] Creating temporary backup directory..."
mkdir -p "$BACKUP_DIR/user_config" "$BACKUP_DIR/user_local_share" "$BACKUP_DIR/sddm_etc" "$BACKUP_DIR/sddm_usr" "$BACKUP_DIR/plymouth_usr" "$BACKUP_DIR/plymouth_etc" "$BACKUP_DIR/dracut_etc"

echo "[+] Backing up Power, Input Devices & Display Profiles..."
cp ~/.config/powermanagementprofilesrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kscreenlockerrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kcminputrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp -r ~/.config/kscreen/ "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Panels, Widgets, Desktop Layouts, KRunner & Shortcuts..."
cp ~/.config/plasmashellrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/plasmarc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kglobalshortcutsrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/khotkeysrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/krunnerrc "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Themes, Fonts, Konsole, KWin & Application Rules..."
cp ~/.config/kdeglobals "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kcmfonts "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/konsolerc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kwinrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/kwinrulesrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/breezerc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/ksplashrc "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp ~/.config/spectaclerc "$BACKUP_DIR/user_config/" 2>/dev/null || true

echo "[+] Backing up Custom Installed Assets & Profiles..."
cp -r ~/.local/share/plasma/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/icons/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/themes/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/wallpapers/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/aurorae/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/color-schemes/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/konsole/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true
cp -r ~/.local/share/fonts/ "$BACKUP_DIR/user_local_share/" 2>/dev/null || true

echo "[+] Backing up Plymouth Themes, System Configs & Dracut (sudo required)..."
if [ -d /usr/share/plymouth/themes ]; then
    sudo cp -r /usr/share/plymouth/themes/ "$BACKUP_DIR/plymouth_usr/" 2>/dev/null || true
fi
if [ -d /etc/plymouth ]; then
    sudo cp -r /etc/plymouth/ "$BACKUP_DIR/plymouth_etc/" 2>/dev/null || true
fi
if [ -d /etc/dracut.conf.d ]; then
    sudo cp -r /etc/dracut.conf.d/ "$BACKUP_DIR/dracut_etc/" 2>/dev/null || true
fi

echo "[+] Backing up SDDM Configuration & Themes (sudo required)..."
if [ -d /etc/sddm.conf.d ]; then
    sudo cp -r /etc/sddm.conf.d/ "$BACKUP_DIR/sddm_etc/" 2>/dev/null || true
fi
if [ -f /etc/sddm.conf ]; then
    sudo cp /etc/sddm.conf "$BACKUP_DIR/sddm_etc/" 2>/dev/null || true
fi
if [ -d /usr/share/sddm/themes ]; then
    sudo cp -r /usr/share/sddm/themes/ "$BACKUP_DIR/sddm_usr/" 2>/dev/null || true
fi

# Fix permissions on temporary staging folder before archiving
sudo chown -R "$USER:$USER" "$BACKUP_DIR"

echo "[+] Compressing into archive ${BACKUP_NAME}.tar.gz..."
tar -czvf "$HOME/${BACKUP_NAME}.tar.gz" -C "$HOME" "$BACKUP_NAME"
rm -rf "$BACKUP_DIR"

echo "[SUCCESS] Complete visual setup backup saved to: $HOME/${BACKUP_NAME}.tar.gz"
