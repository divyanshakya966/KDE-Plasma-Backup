# KDE Plasma 6, Plymouth, SDDM & Bash Configuration Manager

This repository contains automated Bash utilities for backing up and restoring the visual state, ricing configurations, user preferences, boot splash themes, login screen settings, and shell customizations of a customized KDE Plasma desktop environment.

Unlike heavy, full-system snapshot tools, these scripts are precision-targeted. They isolate user interface layouts, widget placements, power management schedules, shortcuts, themes, terminal configurations (`~/.bashrc` and **ble.sh** data), Plymouth boot screens, and SDDM customizations, making it easy to port your exact desktop experience across different machines or recover from a visual breakage.

## Features

* **Targeted Backups:** Captures dotfiles (`~/.bashrc`), local share assets (`~/.local/share/blesh/`), Plymouth boot themes/configs, Dracut rules, and display manager configs.


* **Complete Visual & Behavior Portability:** Backs up panels, custom widgets (plasmoids), KWin rules, window decorations, global shortcuts, input device speeds, and font rendering settings.


* **App & Utility Configs:** Saves preferences for built-in tools like KRunner, Konsole, Spectacle, and shell environment rules.


* **Boot & Login Integration:** Preserves Plymouth themes (`/usr/share/plymouth/themes`), system Plymouth rules (`/etc/plymouth/`), Dracut configurations (`/etc/dracut.conf.d/`), and SDDM themes (`/usr/share/sddm`).


* **Automated Initramfs Rebuild:** Automatically triggers `dracut --regenerate-all --force` upon restoration to bake restored Plymouth boot themes directly into the bootloader image.


* **Timestamped Archives:** Automatically generates cleanly organized, timestamped `.tar.gz` archives for version control and rollback.



## Prerequisites

* **Operating System:** Fedora Workstation (or any system running KDE Plasma 5/6).


* **Dependencies:** Standard coreutils (`cp`, `tar`, `mkdir`, `dracut`).


* **Privileges:** `sudo` access is required *only* for Plymouth boot themes, Dracut, and SDDM configuration portions (backing up and restoring from `/etc` and `/usr/share`).



---

## What Gets Backed Up? (Configuration Mapping)

The scripts target the following specific configurations to ensure a 1:1 recreation of your desktop and shell environment:

| Category | Targeted File / Directory | Description / Purpose |
| --- | --- | --- |
| **Desktop Layout & Widgets** | `plasma-org.kde.plasma.desktop-appletsrc`<br><br>`plasmashellrc`, `plasmarc` | Panel positions, applets, widgets, and overall desktop layout configs.|
| **KWin, Window Rules & UI** | `kwinrc`, `kwinrulesrc`, `breezerc` | Window rules, titlebar decorations, blur effects, and widget styles.|
| **Themes, Colors & Fonts** | `kdeglobals`, `kcmfonts`<br><br>`~/.local/share/fonts/`<br><br>`~/.local/share/color-schemes/` | Global accent colors, custom fonts, DPI scaling, anti-aliasing, and color files.|
| **Input & Peripherals** | `kcminputrc` | Mouse speed, acceleration, and touchpad gestures.|
| **Global Shortcuts** | `kglobalshortcutsrc`, `khotkeysrc` | Keybindings, custom hotkeys, and window action shortcuts.|
| **Power & Display** | `powermanagementprofilesrc`<br><br>`kscreenlockerrc`, `kscreen/`, `ksplashrc` | Sleep timeouts, screen dimming rules, lock screen layout, and splash screens.|
| **Apps & Shell Environment** | `krunnerrc`, `konsolerc`, `spectaclerc`<br><br>`~/.local/share/konsole/`<br><br>`~/.bashrc`, `~/.local/share/blesh/` | KRunner search, Spectacle, Konsole profiles, shell configurations, and **ble.sh** local state files.|
| **Custom Assets** | `~/.local/share/plasma/`, `icons/`, `themes/`, `wallpapers/`, `aurorae/` | Installed plasmoids, icon packs, custom window decorations, and wallpapers.|
| **Plymouth Boot Themes** | `/usr/share/plymouth/themes/`<br><br>`/etc/plymouth/plymouthd.conf`<br><br>`/etc/dracut.conf.d/` | Custom boot screen visuals, active Plymouth theme configuration, and initramfs boot rules.|
| **SDDM Login Configs** | `/etc/sddm.conf.d/`, `/etc/sddm.conf` | System login manager settings, auto-login rules, and display overrides.|
| **SDDM Login Themes** | `/usr/share/sddm/themes/` | Custom login screen visual theme assets (QML, images, backgrounds).|

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

3. **Provide Elevated Privileges:** The script will prompt for your `sudo` password to securely copy system-level Plymouth boot themes, Dracut configs, and SDDM settings from root-owned directories.


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

3. **Apply Changes:** The script automatically attempts to restart the Plasma shell, restore user dotfiles like `~/.bashrc`, and regenerate your initramfs image via `dracut`. For full application of Plymouth boot splash screens, SDDM, KWin rules, fonts, and input devices, **reboot your system**.



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

### 2. Removing Root / Plymouth / SDDM Requirements

If you want to run this script as a purely user-level automation job without manual `sudo` intervention, you can strip out system-level tracking.

* **In the backup script:** Delete or comment out the entire Plymouth and SDDM blocks.


* **In the restore script:** Delete or comment out the corresponding system restoration and `dracut` rebuild blocks.


* *Result:* The scripts will now execute 100% in user-space without ever prompting for a root password.



### 3. Changing the Output Directory

By default, backups are saved to `$HOME`. To route them to an external drive or a dedicated backup folder, modify the `BACKUP_DIR` and `tar` destination variables at the bottom of the backup script:

```bash
# Change this line in backup-kde-rice.sh to target a new path
tar -czvf "/mnt/external_drive/Backups/${BACKUP_NAME}.tar.gz" -C "$HOME" "$BACKUP_NAME"

```

---

## Security & Automation Best Practices

* **Secure Storage:** Because these archives contain exact system states and potentially sensitive user configurations (like application layouts or auto-login files), ensure the resulting `.tar.gz` files are stored in directories with restricted read permissions (`chmod 600`).


* **Automated CI/CD or Cron:** If integrating this into an automated pipeline or standard `cron` job, remove the `sudo` Plymouth, Dracut, and SDDM prompts to prevent the script from hanging while waiting for standard input.


* **Validation:** Regularly test your restoration script on a virtual machine or a secondary user account to ensure the structural integrity of the archives.
