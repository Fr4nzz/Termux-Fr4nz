#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="${CONTAINER:-$HOME/containers/ubuntu-proot}"
U="${DESKTOP_USER:-}"

# Ask for desktop username (works even when piped: curl ... | bash)
if [ -z "$U" ]; then
  read -rp "Desktop username [legend]: " U </dev/tty || true
  U="${U:-legend}"
fi

# Ask about Zsh installation immediately after username
INSTALL_ZSH="${INSTALL_ZSH:-}"
if [ -z "$INSTALL_ZSH" ]; then
  read -rp "Install Zsh + Oh My Zsh in container? [Y/n]: " INSTALL_ZSH </dev/tty || true
  INSTALL_ZSH="${INSTALL_ZSH:-Y}"
fi

REPO_RAW="https://raw.githubusercontent.com/Fr4nzz/Termux-Fr4nz/refs/heads/main"

pkg update -y >/dev/null || true
pkg install -y proot python >/dev/null

# Helper: run a command inside the proot container
prun() {
  proot-run -r "$C" -b "$PREFIX/tmp/.X11-unix:/tmp/.X11-unix" -b /sdcard:/mnt/sdcard \
    /usr/bin/env -i HOME=/root TERM=xterm-256color \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$@"
}

# Install proot-run wrapper (replaces deprecated daijin)
if ! command -v proot-run >/dev/null 2>&1; then
  echo "[rootless] Installing proot-run wrapper..."
  curl -fsSL "$REPO_RAW/termux-scripts/proot_run.sh" -o "$PREFIX/bin/proot-run"
  chmod 0755 "$PREFIX/bin/proot-run"
fi

# Install rurima for image pulling
if ! command -v rurima >/dev/null 2>&1; then
  echo "[rootless] Installing rurima..."
  curl -fsSL "$REPO_RAW/termux-scripts/install_rurima.sh" | bash
fi

# Pull Ubuntu rootfs
mkdir -p "$(dirname "$C")"
[ -d "$C" ] || rurima lxc pull -o ubuntu -v noble -s "$C"

# Android fixup: create groups needed for networking (aid_inet etc.)
prun /bin/sh <<'FIXUP'
set -e
PATH=$PATH:/bin:/sbin:/usr/bin
for spec in \
  aid_system:1000 aid_radio:1001 aid_bluetooth:1002 aid_graphics:1003 \
  aid_input:1004 aid_audio:1005 aid_camera:1006 aid_log:1007 \
  aid_compass:1008 aid_mount:1009 aid_wifi:1010 aid_adb:1011 \
  aid_install:1012 aid_media:1013 aid_dhcp:1014 aid_sdcard_rw:1015 \
  aid_vpn:1016 aid_keystore:1017 aid_usb:1018 aid_drm:1019 \
  aid_mdnsr:1020 aid_gps:1021 aid_media_rw:1023 aid_mtp:1024 \
  aid_drmrpc:1026 aid_nfc:1027 aid_sdcard_r:1028 aid_clat:1029 \
  aid_loop_radio:1030 aid_media_drm:1031 aid_package_info:1032 \
  aid_sdcard_pics:1033 aid_sdcard_av:1034 aid_sdcard_all:1035 \
  aid_logd:1036 aid_shared_relro:1037 aid_dbus:1038 aid_tlsdate:1039 \
  aid_media_ex:1040 aid_audioserver:1041 aid_metrics_coll:1042 \
  aid_metricsd:1043 aid_webserv:1044 aid_debuggerd:1045 \
  aid_media_codec:1046 aid_cameraserver:1047 aid_firewall:1048 \
  aid_trunks:1049 aid_nvram:1050 aid_dns:1051 aid_dns_tether:1052 \
  aid_webview_zygote:1053 aid_vehicle_network:1054 \
  aid_media_audio:1055 aid_media_video:1056 aid_media_image:1057 \
  aid_tombstoned:1058 aid_media_obb:1059 aid_ese:1060 \
  aid_ota_update:1061 aid_automotive_evs:1062 aid_lowpan:1063 \
  aid_hsm:1064 aid_reserved_disk:1065 aid_statsd:1066 \
  aid_incidentd:1067 aid_secure_element:1068 aid_lmkd:1069 \
  aid_llkd:1070 aid_iorapd:1071 aid_gpu_service:1072 \
  aid_network_stack:1073 aid_shell:2000 aid_cache:2001 aid_diag:2002 \
  aid_net_bt_admin:3001 aid_net_bt:3002 aid_inet:3003 \
  aid_net_raw:3004 aid_net_admin:3005 aid_net_bw_stats:3006 \
  aid_net_bw_acct:3007 aid_readproc:3009 aid_wakelock:3010 \
  aid_uhid:3011 aid_everybody:9997 aid_misc:9998 aid_nobody:9999 \
  aid_user_offset:100000; do
  name="${spec%%:*}"; gid="${spec##*:}"
  groupadd "$name" -g "$gid" 2>/dev/null || true
done

# Add root to all Android groups for networking + hardware access
ALL_GROUPS=$(getent group | grep '^aid_' | cut -d: -f1 | paste -sd, -)
[ -n "$ALL_GROUPS" ] && usermod -a -G "$ALL_GROUPS" root 2>/dev/null || true

# Fix apt networking
usermod -g aid_inet _apt 2>/dev/null || true

# Fix permissions
[ -e /bin/su ] && chmod 777 /bin/su
for d in /dev /proc /sys; do [ -e "$d" ] || mkdir -p "$d"; done

# Fix DNS
printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
FIXUP

# Base tools
prun /bin/sh <<'SH'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg wget python3
SH

# Maintainer helpers so adduser & postinsts work
prun /bin/sh <<'SH'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  debconf debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata \
  sgml-base xml-core
dpkg --configure -a || true
apt-get -o Dpkg::Options::="--force-confnew" -f install
SH

# myip helper
prun /bin/sh <<'SH'
set -e
cat >/usr/local/bin/myip <<'PYSH'
#!/bin/sh
python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect(("1.1.1.1",80))
print(s.getsockname()[0])
s.close()
PY
PYSH
chmod 0755 /usr/local/bin/myip
SH

# Create desktop user + sudo NOPASSWD + runtime markers
prun /bin/sh <<SH
set -e
U="$U"
if [ -z "\$U" ] || printf '%s' "\$U" | grep -Eq '^-'; then
  echo "Invalid username: \$U"; exit 1
fi
if ! printf '%s' "\$U" | grep -Eq '^[A-Za-z0-9_.@-]+\$'; then
  echo "Invalid username: \$U"; exit 1
fi
/usr/sbin/adduser --disabled-password --gecos '' "\$U" || true
/usr/sbin/adduser "\$U" sudo || true
/usr/bin/install -d -m0755 /etc/sudoers.d
echo "\$U ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-\$U
/bin/chmod 0440 /etc/sudoers.d/99-\$U
/usr/bin/install -d -m0755 /etc/ruri
printf '%s\n' "\$U" > /etc/ruri/user
printf '%s\n' proot > /etc/ruri/runtime
/usr/bin/install -d -m0700 -o "\$U" -g "\$U" /home/"\$U"/.run
echo 'export TERM=xterm-256color' >> /root/.bashrc
/bin/su - "\$U" -c "echo 'export TERM=xterm-256color' >> ~/.bashrc"
SH

# Termux -> container wrappers
TP="$PREFIX/tmp/.X11-unix"
mkdir -p "$TP" "$PREFIX/bin"

# Host-side helper: phone-ip
cat >"$PREFIX/bin/phone-ip" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.connect(("1.1.1.1",80))
print(s.getsockname()[0])
s.close()
PY
SH
chmod 0755 "$PREFIX/bin/phone-ip"

cat >"$PREFIX/bin/ubuntu-proot" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
: "${PREFIX:=/data/data/com.termux/files/usr}"
C="$HOME/containers/ubuntu-proot"
TP="$PREFIX/tmp/.X11-unix"; [ -d "$TP" ] || mkdir -p "$TP"

# Parse --user flag
U="root"
if [ "$1" = "--user" ]; then
  U="$2"
  shift 2
  [ "$#" -gt 0 ] && echo "Warning: --user only works for interactive mode" >&2 && U="root"
fi

# Clear problematic environment variables
unset SHELL ZDOTDIR ZSH OH_MY_ZSH

BIND="-b $TP:/tmp/.X11-unix -b /sdcard:/mnt/sdcard"

# Piped input check FIRST
if [ ! -t 0 ]; then
  exec proot-run -r "$C" -e "$BIND" \
    /usr/bin/env -i \
      HOME=/root \
      TERM="${TERM:-xterm-256color}" \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      "${@:-/bin/bash}"
fi

# No args -> interactive
[ "$#" -eq 0 ] && exec proot-run -r "$C" -e "$BIND" /bin/su - "$U"

# Command - use simple env approach
exec proot-run -r "$C" -e "$BIND" \
  /usr/bin/env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root \
  "$@"
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot"

cat >"$PREFIX/bin/ubuntu-proot-u" <<'SH'
#!/data/data/com.termux/files/usr/bin/sh
C="$HOME/containers/ubuntu-proot"
pkill -f "proot .*${C}" || true
SH
chmod 0755 "$PREFIX/bin/ubuntu-proot-u"

# Install Zsh based on earlier answer
case "$INSTALL_ZSH" in
  [Yy]*|"")
    echo "[*] Installing Zsh in container..."
    if curl -fsSL "$REPO_RAW/container-scripts/install_zsh.sh" \
      | ubuntu-proot; then
      echo "✅ Zsh installed in container"
    else
      echo "⚠️  Zsh installation failed or skipped"
    fi
    ;;
  *)
    echo "Skipping Zsh installation"
    ;;
esac

echo "✅ Rootless container ready. Enter with: ubuntu-proot"
echo ""
