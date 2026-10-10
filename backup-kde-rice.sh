#!/bin/bash
#
# backup-kde-rice.sh
# Full Fedora KDE Plasma backup: user configs, dotfiles, app configs,
# system configuration (/etc), system-wide themes/assets, package lists
# (dnf + flatpak + copr + systemd units) and boot theme assets.
#
# Output: ~/kde_rice_backup_YYYYMMDD_HHMMSS.tar.gz  (+ .sha256)
#
set -euo pipefail

# ------------------------------------------------------------------ config
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="kde_rice_backup_${TIMESTAMP}"
STAGE="$HOME/.${BACKUP_NAME}.stage"
ARCHIVE="$HOME/${BACKUP_NAME}.tar.gz"

# Set INCLUDE_USER_DATA=1 to also archive ~/Documents, ~/Pictures, ~/Music,
# ~/Videos, ~/Downloads, ~/Desktop and ~/GitHub. Off by default.
INCLUDE_USER_DATA="${INCLUDE_USER_DATA:-0}"

# ------------------------------------------------------------------ helpers
c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_blue='\033[1;36m'; c_off='\033[0m'
log()  { printf "${c_green}[+ ]${c_off} %s\n" "$*"; }
info() { printf "${c_blue}[ i]${c_off} %s\n" "$*"; }
warn() { printf "${c_yellow}[ !]${c_off} %s\n" "$*" >&2; }
die()  { printf "${c_red}[ x]${c_off} %s\n" "$*" >&2; exit 1; }

cleanup() { sudo rm -rf "$STAGE" 2>/dev/null || rm -rf "$STAGE" 2>/dev/null || true; }
KEEPALIVE_PID=""
on_exit() {
    [ -n "$KEEPALIVE_PID" ] && kill "$KEEPALIVE_PID" 2>/dev/null || true
    cleanup
}
trap on_exit EXIT INT TERM

# ------------------------------------------------------------------ checks
[ "$(id -u)" -ne 0 ] || die "Do not run as root. Run as your normal user (sudo will be requested)."
for t in rsync tar dnf rpm; do
    command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"
done

log "Requesting sudo privileges (needed for /etc, /usr/share and /boot)..."
sudo -v || die "sudo is required to back up system configuration."
# Keep sudo timestamp alive for the whole run.
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit 0; done ) &
KEEPALIVE_PID=$!

# Free-space sanity check (staging + archive). Home configs ~3-5 GB typical.
AVAIL_KB=$(df -Pk "$HOME" | awk 'NR==2{print $4}')
if [ "$AVAIL_KB" -lt 8000000 ]; then
    warn "Less than ~8 GB free in $HOME. Backup may fail. Continuing anyway."
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"/{home,etc,usr,boot,packages}
chmod 700 "$STAGE"

# ------------------------------------------------------------------ 1. user
log "Backing up user dotfiles, app configs and local assets..."

# Include every top-level dotfile/dotdir (and their contents), then drop
# caches, package caches, game/steam data and other regenerable heavy dirs.
cat > "$STAGE/.home-filters" <<'EOF'
# --- never archive our own staging dir / previous archives ---
- .kde_rice_backup_*.stage/
- .kde_rice_backup_*.tar.gz*
# --- exclude heavy / regenerable data (first match wins) ---
- .cache/
- .npm/
- .bun/
- .cargo/
- .rustup/
- .nvm/
- node_modules/
- .local/share/Steam/
- .local/share/Trash/
- .local/share/baloo/
- .local/share/kactivitymanagerd/
- .local/share/containers/
- .local/share/flatpak/
- .local/share/recently-used.xbel*
- .var/app/org.vinegarhq.Sober/
- .var/app/*/cache/
- .var/app/*/Cache/
- cache2/
- Cache/
- Code Cache/
- CachedData/
- GPUCache/
- CacheStorage/
- blob_storage/
- Service Worker/
- Crashpad/
- Crash Reports/
- */logs/
- *.log
# --- include all top-level hidden entries recursively ---
+ /.*/
+ /.*/**
+ /.*
# --- exclude everything non-hidden (normal user data) ---
- *
EOF

if [ "$INCLUDE_USER_DATA" = "1" ]; then
    info "INCLUDE_USER_DATA=1 -> also archiving ~/Documents ~/Pictures ~/Music ~/Videos ~/Downloads ~/Desktop ~/GitHub"
    for d in Documents Pictures Music Videos Downloads Desktop GitHub; do
        [ -e "$HOME/$d" ] && { mkdir -p "$STAGE/home/$d"; rsync -aHAX "$HOME/$d/" "$STAGE/home/$d/"; }
    done
fi

rsync -aHAX --numeric-ids --filter="merge $STAGE/.home-filters" "$HOME/." "$STAGE/home/"
rm -f "$STAGE/.home-filters"

# ------------------------------------------------------------------ 2. /etc
log "Backing up system configuration (/etc)..."
# Full copy. Volatile runtime files are skipped. Restore applies its own
# safety exclusions (see restore script).
sudo rsync -aHAX --numeric-ids \
    --exclude='mtab' \
    --exclude='.pwd.lock' \
    --exclude='subgid.lock' \
    --exclude='subuid.lock' \
    --exclude='*~' \
    /etc/ "$STAGE/etc/"

# ------------------------------------------------------------------ 3. /usr
log "Backing up system-wide themes, icons, fonts and KDE assets..."
SHARE_DIRS=(
    /usr/share/sddm/themes
    /usr/share/plymouth/themes
    /usr/share/themes
    /usr/share/icons
    /usr/share/fonts
    /usr/share/plasma
    /usr/share/color-schemes
    /usr/share/aurorae
    /usr/share/konsole
    /usr/share/wallpapers
    /usr/share/backgrounds
    /usr/share/grub/themes
    /usr/share/xsessions
    /usr/share/wayland-sessions
    /usr/share/kservices5
    /usr/share/kservices6
    /usr/local/share
)
EXISTING=()
for d in "${SHARE_DIRS[@]}"; do [ -e "$d" ] && EXISTING+=("$d"); done
if [ "${#EXISTING[@]}" -gt 0 ]; then
    sudo rsync -aHAXR --numeric-ids "${EXISTING[@]}" "$STAGE/"
fi

# /opt: apps installed manually to /opt (e.g. Discord, Packet Tracer).
if [ -d /opt ] && [ -n "$(ls -A /opt 2>/dev/null)" ]; then
    log "Backing up /opt (manual app installs)..."
    sudo rsync -aHAXR --numeric-ids /opt "$STAGE/"
fi

# ------------------------------------------------------------------ 4. boot
log "Backing up GRUB theme assets..."
if [ -d /boot/grub2/themes ]; then
    sudo rsync -aHAXR --numeric-ids /boot/grub2/themes "$STAGE/"
fi
if [ -d /boot/grub/themes ]; then
    sudo rsync -aHAXR --numeric-ids /boot/grub/themes "$STAGE/"
fi

# ------------------------------------------------------------- 5. crontabs
log "Backing up cron spool..."
if [ -d /var/spool/cron ]; then
    sudo rsync -aHAXR --numeric-ids /var/spool/cron "$STAGE/" || true
fi

# ------------------------------------------------------ 6. package lists
log "Collecting installed package lists, repos and enabled services..."
P="$STAGE/packages"
dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u > "$P/rpm-userinstalled.txt" || true
rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort -u > "$P/rpm-all.txt" || true
dnf copr list 2>/dev/null | grep -v '^$' > "$P/copr-repos.txt" || true
dnf group list --installed --hidden 2>/dev/null | sed -n '/^Installed Environment Groups:/,/^$/p;/^Installed Groups:/,/^$/p' > "$P/dnf-groups.txt" || true
flatpak remotes --columns=name,url 2>/dev/null > "$P/flatpak-remotes.txt" || true
flatpak list --app --columns=ref 2>/dev/null > "$P/flatpak-apps.txt" || true
flatpak list --runtime --columns=ref 2>/dev/null > "$P/flatpak-runtimes.txt" || true
systemctl list-unit-files --state=enabled --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sort -u > "$P/systemd-enabled-units.txt" || true
systemctl --user list-unit-files --state=enabled --no-legend --no-pager 2>/dev/null | awk '{print $1}' | sort -u > "$P/systemd-user-enabled-units.txt" || true

# ------------------------------------------------------------------ 7. meta
log "Writing metadata manifest..."
{
    echo "backup_name=$BACKUP_NAME"
    echo "created=$(date -Is)"
    echo "hostname=$(hostname)"
    echo "fedora_release=$(rpm -E %fedora 2>/dev/null || true)"
    echo "os_pretty=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- )"
    echo "kernel=$(uname -r)"
    echo "arch=$(uname -m)"
    echo "plasma_version=$(plasmashell --version 2>/dev/null || true)"
    echo "kwin_version=$(kwin_wayland --version 2>/dev/null || kwin_x11 --version 2>/dev/null || true)"
    echo "user=$USER"
    echo "uid=$(id -u)"
    echo "gid=$(id -g)"
    echo "include_user_data=$INCLUDE_USER_DATA"
} > "$STAGE/META.txt"

# --------------------------------------------------------------- 8. archive
log "Creating archive ${BACKUP_NAME}.tar.gz ..."
sudo tar --acls --xattrs --selinux --numeric-owner -cpzf "$ARCHIVE" -C "$HOME" ".${BACKUP_NAME}.stage"
sudo chown "$(id -u):$(id -g)" "$ARCHIVE"
chmod 600 "$ARCHIVE"

log "Generating checksum..."
( cd "$HOME" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256" )
chmod 600 "${ARCHIVE}.sha256"

SIZE=$(du -h "$ARCHIVE" | cut -f1)
log "Done. Archive: $ARCHIVE  (${SIZE})"
log "Checksum:   ${ARCHIVE}.sha256"
info "Keep these files private (chmod 600): they contain passwords, keys and tokens."
