#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ubuntu-chroot /bin/bash -lc '
export DEBIAN_FRONTEND=noninteractive
sudo install -d /usr/sbin
sudo tee /usr/sbin/policy-rc.d >/dev/null <<EOF
#!/bin/sh
exit 101
EOF
sudo chmod +x /usr/sbin/policy-rc.d
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends debconf
sudo apt-get install -y --reinstall --no-install-recommends debconf-i18n init-system-helpers perl-base adduser dialog locales tzdata
sudo apt-get install -y --reinstall --no-install-recommends sgml-base xml-core
sudo dpkg --configure -a || true
sudo apt-get -o Dpkg::Options::="--force-confnew" -f install
sudo apt-get install -y --no-install-recommends xfce4 xfce4-session xfce4-terminal dbus dbus-x11 xterm fonts-dejavu-core x11-utils psmisc
sudo sed -i "s/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
sudo locale-gen en_US.UTF-8
sudo dbus-uuidgen --ensure
sudo install -d -m 0755 /run/dbus
echo "✅ XFCE installed (rooted). Use xfce4-chroot-start / xfce4-chroot-stop."
'
