#!/bin/bash
set -euo pipefail

echo "==> Cleaning yum/dnf cache..."
dnf clean all
rm -rf /var/cache/dnf

echo "==> Removing machine-id..."
truncate -s 0 /etc/machine-id

echo "==> Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo "==> Clearing logs..."
find /var/log -type f -exec truncate -s 0 {} \;

echo "==> Clearing temp and history..."
rm -rf /tmp/* /var/tmp/*
unset HISTFILE
rm -f /root/.bash_history /home/*/.bash_history

echo "==> Cleanup complete."
