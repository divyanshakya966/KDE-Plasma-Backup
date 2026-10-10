# Fedora KDE Plasma Full Backup & Restore

Bash utilities that snapshot and rebuild an entire customized Fedora KDE Plasma
setup on a fresh install: desktop look, all user configs and dotfiles, system
configuration, boot/login theming, and the complete installed application set
(RPM, Flatpak, COPR repos and enabled services).

Two scripts:

- `backup-kde-rice.sh` — builds `~/kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz`
- `restore-kde-rice.sh` — rebuilds the machine from that archive

Both require `sudo` (to read/write `/etc`, `/usr/share`, `/boot`). The archive
contains sensitive data (passwords, WiFi keys, SSH/GPG material, tokens), so it
is written `chmod 600` and a `.sha256` checksum is generated next to it.

---

## What gets backed up

| Category | Source | Notes |
| --- | --- | --- |
| **User configs** | `~/.config/` | Entire directory: Plasma, KWin (`kwinoutputconfig.json`, `kwinrc`), Powerdevil (`powerdevilrc`), KRunner, Konsole, Spectacle, GTK/Qt, KDE Connect, app configs, etc. |
| **User local assets** | `~/.local/share/`, `~/.local/bin`, `~/.local/state` | Plasmoids, themes, icons, fonts, wallpapers, aurorae, color-schemes, Konsole profiles, clipboard history, custom `.desktop` files. |
| **Dotfiles** | every top-level `~/.<name>` | `.bashrc`, `.profile`, `.bash_history`, `.gitconfig`, `.gtkrc-2.0`, `.ssh`, `.gnupg`, shell/misc configs. |
| **Flatpak app data** | `~/.var/` | App configs/data (caches excluded). |
| **System config** | `/etc/` | Full copy: SDDM, Plymouth, dracut, NetworkManager connections, cron, systemd units, dnf repos, firewalld, X11/Xorg, modprobe, udev, etc. |
| **System themes/assets** | `/usr/share/{sddm,themes,icons,fonts,plasma,color-schemes,aurorae,konsole,wallpapers,backgrounds,grub}/`, `/usr/share/plymouth/themes`, `/usr/share/{xsessions,wayland-sessions}`, `/usr/local/share` | System-wide installed look-and-feel, login/boot themes and fonts. |
| **Boot theme assets** | `/boot/grub2/themes` | GRUB theme files. |
| **Cron spool** | `/var/spool/cron` | User/root crontabs. |
| **Package list** | `packages/rpm-userinstalled.txt` | `dnf repoquery --userinstalled` (clean package names, no versions). |
| **Full RPM list** | `packages/rpm-all.txt` | Fallback inventory from `rpm -qa`. |
| **Repos** | `packages/copr-repos.txt` | COPR repositories (`/etc/yum.repos.d` and GPG keys are in `/etc`). |
| **Flatpak** | `packages/flatpak-{remotes,apps,runtimes}.txt` | Remotes and exact app refs. |
| **Services** | `packages/systemd-{enabled,systemd-user-enabled}-units.txt` | Enabled system and user units. |
| **Metadata** | `META.txt` | Hostname, Fedora/Plasma version, kernel, arch, user/uid/gid. |

Heavy, regenerable data is **excluded** by default: `.cache`, `.npm`, `.bun`,
`.cargo`, `.rustup`, `node_modules`, Steam, browser/Electron caches, Trash,
baloo/kactivity indexes, container/flatpak runtimes.

Normal user data (`Documents`, `Pictures`, `Music`, `Videos`, `Downloads`,
`Desktop`, `GitHub`) is **not** included unless you run the backup with
`INCLUDE_USER_DATA=1`:

```bash
INCLUDE_USER_DATA=1 ./backup-kde-rice.sh
```

---

## Usage

### 1. Back up

```bash
chmod +x backup-kde-rice.sh
./backup-kde-rice.sh
# or, to also include your personal files:
INCLUDE_USER_DATA=1 ./backup-kde-rice.sh
```

Output (in `$HOME`):

```
kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz
kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz.sha256
```

Copy both files somewhere safe (external drive / cloud). They are unencrypted —
protect them.

### 2. Restore onto a fresh Fedora KDE install

```bash
chmod +x restore-kde-rice.sh
./restore-kde-rice.sh /path/to/kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz
# add -y to skip the confirmation prompt
```

The restore script will:

1. Verify the checksum (aborts if it fails).
2. Restore `/etc` (machine/disk/account-specific files are skipped — see below).
3. Reinstall all RPM packages, Flatpak remotes + apps.
4. Restore system themes/assets, GRUB themes and cron jobs.
5. Restore your home dotfiles and app configs.
6. Rebuild font/icon/service caches (`fc-cache`, `kbuildsycoca6`, desktop DBs).
7. Re-enable enabled systemd system/user units.
8. Fix SELinux file contexts (`restorecon`).
9. Rebuild the initramfs (Plymouth) and GRUB menu.

Then **reboot**.

---

## Safety

The restore is intentionally conservative so a fresh install does **not** break:

- It **never restores** `/etc/fstab`, `/etc/crypttab`, `/etc/machine-id`,
  `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/subuid`, `/etc/subgid`,
  `/etc/resolv.conf`, `/etc/selinux/` or `/etc/nvme/`. Disk layout, login
  accounts and system identity stay exactly as the fresh installer created them.
- It verifies the SHA-256 checksum before touching anything.
- It requires an explicit `yes` confirmation (unless `-y`).

Notes / caveats:

- The archive is **unencrypted**. Store it securely and delete old copies.
- Restoring a backup from a *different* Fedora major version may install
  mismatched packages; prefer same-version backups.
- Reinstalling ~470 RPMs and building initramfs can take a long time.

---

## Manual checks after restore

If something looks off, the usual culprits and fixes:

```bash
# fonts not showing
fc-cache -f && kbuildsycoca6 --noincremental

# monitor layout wrong (edit ~/.config/kwinoutputconfig.json or use System Settings)
# services not started
systemctl --failed ; systemctl --user --failed

# SELinux denials after copying old configs
sudo restorecon -RF /etc /usr/share /home/$USER
```

To add more apps, edit the `SHARE_DIRS` array or the filter list in
`backup-kde-rice.sh`.

---

## License

Released under the MIT License. See [LICENSE](LICENSE).
