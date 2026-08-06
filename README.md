# KDE Plasma 6 & SDDM Configuration Manager

This repository contains automated Bash utilities for backing up and restoring the visual state, ricing configurations, user preferences, and login screen themes of a customized KDE Plasma desktop environment. 

Unlike heavy, full-system snapshot tools, these scripts are precision-targeted. They isolate user interface layouts, widget placements, power management schedules, shortcuts, themes, terminal profiles, and SDDM customizations, making it easy to port your exact desktop experience across different machines or recover from a visual breakage.

## Features

* **Targeted Backups:** Captures only dotfiles, local share assets, and display manager configs. Leaves heavy personal files and OS binaries untouched.
* **Complete Visual & Behavior Portability:** Backs up panels, custom widgets (plasmoids), KWin rules, window decorations, global shortcuts, input device speeds, and font rendering settings.
* **App & Utility Configs:** Saves preferences for built-in tools like KRunner, Konsole, and Spectacle.
* **SDDM Integration:** Preserves both system-wide SDDM themes (`/usr/share/sddm`) and user override configs (`/etc/sddm.conf.d/`).
* **Timestamped Archives:** Automatically generates cleanly organized, timestamped `.tar.gz` archives for version control and rollback.

## Prerequisites

* **Operating System:** Fedora Workstation (or any system running KDE Plasma 5/6).
* **Dependencies:** Standard coreutils (`cp`, `tar`, `mkdir`).
* **Privileges:** `sudo` access is required *only* for the SDDM configuration portions (backing up and restoring from `/etc` and `/usr/share`).

---

## What Gets Backed Up? (Configuration Mapping)

The scripts target the following specific configurations to ensure a 1:1 recreation of your desktop experience:

| Category | Targeted File / Directory | Description / Purpose |
| :--- | :--- | :--- |
| **Desktop Layout & Widgets** | `plasma-org.kde.plasma.desktop-appletsrc`<br>`plasmashellrc`, `plasmarc` | Panel positions, applets, widgets, and overall desktop layout configs. |
| **KWin, Window Rules & UI** | `kwinrc`, `kwinrulesrc`, `breezerc` | Window rules, titlebar decorations, blur effects, and widget styles. |
| **Themes, Colors & Fonts** | `kdeglobals`, `kcmfonts`<br>`~/.local/share/fonts/`<br>`~/.local/share/color-schemes/` | Global accent colors, custom fonts, DPI scaling, anti-aliasing, and color files. |
| **Input & Peripherals** | `kcminputrc` | Mouse speed, acceleration, and touchpad gestures. |
| **Global Shortcuts** | `kglobalshortcutsrc`, `khotkeysrc` | Keybindings, custom hotkeys, and window action shortcuts. |
| **Power & Display** | `powermanagementprofilesrc`<br>`kscreenlockerrc`, `kscreen/`, `ksplashrc` | Sleep timeouts, screen dimming rules, lock screen layout, and splash screens. |
| **Apps & Utilities** | `krunnerrc`, `konsolerc`, `spectaclerc`<br>`~/.local/share/konsole/` | KRunner search behavior, Spectacle screenshot rules, Konsole profiles & colors. |
| **Custom Assets** | `~/.local/share/plasma/`, `icons/`, `themes/`, `wallpapers/`, `aurorae/` | Installed plasmoids, icon packs, custom window decorations, and wallpapers. |
| **SDDM Login Configs** | `/etc/sddm.conf.d/`, `/etc/sddm.conf` | System login manager settings, auto-login rules, and display overrides. |
| **SDDM Themes** | `/usr/share/sddm/themes/` | Custom login screen visual theme assets (QML, images, backgrounds). |

---

## Usage Guide

### 1. Backing Up Your Configuration

The `backup-kde-rice.sh` script gathers your current configurations and bundles them into a compressed archive in your Home directory.

1. **Make the script executable:**
```bash
chmod +x backup-kde-rice.sh

```

2. **Execute the backup:**
```bash
./backup-kde-rice.sh

```


3. **Provide Elevated Privileges:** The script will prompt for your `sudo` password to securely copy SDDM configuration files from root-owned directories.
4. **Output:** A file named `kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz` will be generated in your home folder.

### 2. Restoring Your Configuration

The `restore-kde-rice.sh` script extracts a designated backup archive and maps the files back to their appropriate system and user directories.

1. **Make the script executable:**
```bash
chmod +x restore-kde-rice.sh

```


2. **Run the restore command** (pass the archive file as an argument):
```bash
./restore-kde-rice.sh kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz

```


3. **Apply Changes:** Once the script finishes, it will automatically attempt to restart the Plasma shell. For a complete application of SDDM, KWin rules, fonts, and input devices, **log out and log back in** (or reboot).

---

## Modifying & Extending the Scripts

The scripts are designed to be easily modified. You can adapt them to track additional applications or alter their behavior by editing the `.sh` files directly.

### 1. Adding New Applications (e.g., Kitty, Fastfetch, Kvantum)

If you heavily customize terminal emulators or specific theming engines, you should add them to the backup script. Open `backup-kde-rice.sh` and add a new `cp` line under the appropriate section:

```bash
# Example: Adding Kitty terminal and Kvantum themes to backup
cp -r ~/.config/kitty "$BACKUP_DIR/user_config/" 2>/dev/null || true
cp -r ~/.config/Kvantum "$BACKUP_DIR/user_config/" 2>/dev/null || true

```

*Don't forget to add corresponding copy commands to the `restore-kde-rice.sh` script if the extraction paths differ, though the standard user configs folder loops automatically.*

### 2. Removing Root / SDDM Requirements

If you want to run this script as a purely user-level automation job without manual `sudo` intervention, you can strip out the SDDM tracking.

* **In the backup script:** Delete or comment out the entire `[+] Backing up SDDM Configuration` block.
* **In the restore script:** Delete or comment out the `[+] Restoring SDDM Configurations` block.
* *Result:* The scripts will now execute 100% in user-space without ever prompting for a root password.

### 3. Changing the Output Directory

By default, backups are saved to `$HOME`. To route them to an external drive or a dedicated backup folder, modify the `BACKUP_DIR` and `tar` destination variables at the bottom of the backup script:

```bash
# Change this line in backup-kde-rice.sh to target a new path
tar -czvf "/mnt/external_drive/Backups/${BACKUP_NAME}.tar.gz" -C "$HOME" "$BACKUP_NAME"

```

---

## Security & Automation Best Practices

* **Secure Storage:** Because these archives contain exact system states and potentially sensitive user configurations (like application layouts or auto-login files), ensure the resulting `.tar.gz` files are stored in directories with restricted read permissions (`chmod 600`), especially if pushing to a remote or cloud backup server.
* **Automated CI/CD or Cron:** If integrating this into an automated pipeline or standard `cron` job, ensure you implement the modifications to remove the `sudo` SDDM prompts (as mentioned above) to prevent the script from hanging while waiting for standard input.
* **Validation:** Regularly test your restoration script on a virtual machine or a secondary user account to ensure the structural integrity of the archives.
