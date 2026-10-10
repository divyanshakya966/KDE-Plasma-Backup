#!/bin/bash
#
# restore-kde-rice.sh
# Restore a full Fedora KDE Plasma backup (created by backup-kde-rice.sh)
# onto a fresh Fedora KDE install: system config, themes/assets, boot theme,
# user dotfiles/app configs and the complete package set (dnf + flatpak).
#
# Usage: ./restore-kde-rice.sh [-y] <path-to-backup.tar.gz>
#   -y / --yes   skip the confirmation prompt
#
set -euo pipefail

# ------------------------------------------------------------------ helpers
c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_blue='\033[1;36m'; c_off='\033[0m'
log()  { printf "${c_green}[+ ]${c_off} %s\n" "$*"; }
info() { printf "${c_blue}[ i]${c_off} %s\n" "$*"; }
warn() { printf "${c_yellow}[ !]${c_off} %s\n" "$*" >&2; }
die()  { printf "${c_red}[ x]${c_off} %s\n" "$*" >&2; exit 1; }

ASSUME_YES=0
ARCHIVE=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes) ASSUME_YES=1 ;;
        -*) die "Unknown option: $arg" ;;
        *) ARCHIVE="$arg" ;;
    esac
done
[ -n "$ARCHIVE" ] || die "Usage: $0 [-y] <path-to-backup.tar.gz>"
[ -f "$ARCHIVE" ] || die "Archive not found: $ARCHIVE"
[ "$(id -u)" -ne 0 ] || die "Do not run as root. Run as your normal user (sudo will be requested)."

TMP="$(mktemp -d /tmp/kde_restore.XXXXXX)"
KEEPALIVE_PID=""
cleanup() { [ -n "$KEEPALIVE_PID" ] && kill "$KEEPALIVE_PID" 2>/dev/null || true; sudo rm -rf "$TMP" 2>/dev/null || rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# ------------------------------------------------------------------ verify
log "Verifying archive integrity..."
if [ -f "${ARCHIVE}.sha256" ]; then
    ( cd "$(dirname "$ARCHIVE")" && sha256sum -c --quiet "$(basename "${ARCHIVE}.sha256")" ) \
        || die "Checksum verification FAILED. Refusing to restore a corrupt/tampered archive."
    info "Checksum OK."
else
    warn "No .sha256 file found next to the archive; skipping checksum verification."
fi

log "Requesting sudo privileges..."
sudo -v || die "sudo is required to restore system configuration."
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit 0; done ) &
KEEPALIVE_PID=$!

log "Extracting archive..."
sudo tar --acls --xattrs --selinux --numeric-owner -xpf "$ARCHIVE" -C "$TMP" --strip-components=1

[ -f "$TMP/META.txt" ] && { echo; sed 's/^/    /' "$TMP/META.txt"; echo; }

if [ "$ASSUME_YES" -ne 1 ]; then
    warn "This will OVERWRITE your current user config, /etc and system theme files."
    read -r -p "Type 'yes' to continue: " ans
    [ "$ans" = "yes" ] || die "Aborted."
fi

# Fix ownership of the user-home payload to the current user (uid may differ).
[ -d "$TMP/home" ] && sudo chown -R "$(id -u):$(id -g)" "$TMP/home"

# ------------------------------------------------------------------ 1. /etc
log "Restoring system configuration (/etc)..."
# These are NOT restored: they are machine/identity/disk specific and would
# break boot or login on a fresh install.
cat > "$TMP/.restore-exclude" <<'EOF'
/passwd
/passwd-
/shadow
/shadow-
/group
/group-
/gshadow
/gshadow-
/subuid
/subuid-
/subgid
/subgid-
/fstab
/fstab.script
/crypttab
/machine-id
/machine-info
/mtab
/resolv.conf
/.updated
/.pwd.lock
/nvme/
/iscsi/initiatorname.iscsi
/selinux/
EOF
sudo rsync -aHAX --numeric-ids --exclude-from="$TMP/.restore-exclude" "$TMP/etc/" /etc/

# Keep the fresh D-Bus machine-id.
info "Machine identity, disk table and account databases kept from the fresh install."

# ------------------------------------------------------------------ 2. pkgs
log "Installing RPM packages (this can take a long time)..."
sudo dnf -y makecache || warn "dnf makecache had issues; continuing."
if [ -s "$TMP/packages/rpm-userinstalled.txt" ]; then
    mapfile -t PKGS < "$TMP/packages/rpm-userinstalled.txt"
    mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | grep -v '^$' | sort -u)
    info "Installing ${#PKGS[@]} user packages from backup..."
    sudo dnf -y install --skip-broken --setopt=install_weak_deps=True "${PKGS[@]}" \
        || warn "Some RPM packages could not be installed. Review the output above."
else
    warn "No RPM package list found in archive; skipping."
fi

log "Restoring Flatpak remotes and applications..."
if [ -s "$TMP/packages/flatpak-remotes.txt" ]; then
    while read -r name url _rest; do
        [ -n "${name:-}" ] && [ -n "${url:-}" ] || continue
        sudo flatpak remote-add --if-not-exists --system "$name" "$url" 2>/dev/null || true
    done < "$TMP/packages/flatpak-remotes.txt"
fi
if [ -s "$TMP/packages/flatpak-apps.txt" ]; then
    info "Installing Flatpak applications..."
    while read -r ref; do
        [ -n "$ref" ] || continue
        sudo flatpak install -y --noninteractive --system "$ref" 2>/dev/null || \
            warn "Flatpak install failed: $ref"
    done < "$TMP/packages/flatpak-apps.txt"
fi

# ------------------------------------------------------------------ 3. usr
log "Restoring system-wide themes, icons, fonts and KDE assets..."
if [ -d "$TMP/usr" ]; then
    sudo rsync -aHAX --numeric-ids "$TMP/usr/" /usr/
fi

log "Restoring GRUB theme assets..."
[ -d "$TMP/boot/grub2/themes" ] && sudo rsync -aHAX --numeric-ids "$TMP/boot/grub2/themes/" /boot/grub2/themes/ || true
[ -d "$TMP/boot/grub/themes" ] && sudo rsync -aHAX --numeric-ids "$TMP/boot/grub/themes/" /boot/grub/themes/ || true

if [ -d "$TMP/var/spool/cron" ]; then
    log "Restoring cron spool..."
    sudo mkdir -p /var/spool/cron
    sudo rsync -aHAX --numeric-ids "$TMP/var/spool/cron/" /var/spool/cron/
fi

# ------------------------------------------------------------------ 4. home
log "Restoring user home dotfiles and application configs..."
if [ -d "$TMP/home" ]; then
    rsync -aHAX "$TMP/home/." "$HOME/"
fi

# ------------------------------------------------------------------ 5. caches
log "Rebuilding font, icon and service caches..."
sudo fc-cache -f >/dev/null 2>&1 || true
fc-cache -f >/dev/null 2>&1 || true
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
sudo gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true

# ------------------------------------------------------------------ 6. units
log "Re-enabling systemd services and user units..."
sudo systemctl daemon-reload || true
if [ -s "$TMP/packages/systemd-enabled-units.txt" ]; then
    while read -r u; do
        [ -n "$u" ] || continue
        sudo systemctl enable "$u" >/dev/null 2>&1 || true
    done < "$TMP/packages/systemd-enabled-units.txt"
    sudo systemctl daemon-reload || true
fi
if [ -s "$TMP/packages/systemd-user-enabled-units.txt" ]; then
    while read -r u; do
        [ -n "$u" ] || continue
        systemctl --user enable "$u" >/dev/null 2>&1 || true
    done < "$TMP/packages/systemd-user-enabled-units.txt"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------ 7. selinux
log "Fixing SELinux file contexts..."
sudo restorecon -RF /etc /usr/share /usr/local /boot /var/spool/cron >/dev/null 2>&1 || true
sudo restorecon -RF "$HOME/.config" "$HOME/.local" "$HOME/.ssh" >/dev/null 2>&1 || true

# ------------------------------------------------------------------ 8. boot
log "Rebuilding initramfs (Plymouth) and GRUB menu..."
if [ -d "$TMP/usr/share/plymouth/themes" ] || [ -d "$TMP/etc/plymouth" ]; then
    if command -v dracut >/dev/null 2>&1; then
        sudo dracut --regenerate-all --force || warn "dracut failed. Run 'sudo dracut --regenerate-all --force' manually."
    fi
fi
if command -v grub2-mkconfig >/dev/null 2>&1 && [ -f /boot/grub2/grub.cfg ]; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg || warn "grub2-mkconfig failed. Run it manually."
fi

# ------------------------------------------------------------------ done
log "Restoration finished."
info "A reboot is strongly recommended so Plymouth, SDDM, KWin, fonts and services apply."
info "Review any [ !] warnings above before rebooting."
