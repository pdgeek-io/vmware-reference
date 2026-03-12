#!/bin/bash
# Template cleanup script — prepares the VM for templatization
set -euo pipefail

echo "==> Cleaning apt cache..."
apt-get -y autoremove
apt-get -y clean

echo "==> Removing machine-id..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo "==> Clearing cloud-init state..."
cloud-init clean --logs --seed

echo "==> Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo "==> Clearing logs..."
find /var/log -type f -exec truncate -s 0 {} \;
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp

echo "==> Clearing temporary files..."
rm -rf /tmp/* /var/tmp/*

echo "==> Clearing shell history..."
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/*/.bash_history

echo "==> Cleanup complete."
