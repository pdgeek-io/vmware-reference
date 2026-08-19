#!/bin/bash
# Narrow CIS-oriented baseline for Ubuntu 24.04 VM templates.
#
# This is a template-build hook, not a full scanner/remediation engine. It sets
# the controls that are safe and useful before Terraform clones the VM:
# auditing, AppArmor, unattended security updates, SSH hardening, sysctl
# hardening, service minimization, and local evidence for downstream validation.
set -euo pipefail

ENABLE_CIS_BASELINE="${ENABLE_CIS_BASELINE:-true}"
CIS_PROFILE="${CIS_PROFILE:-cis-ubuntu-2404-level-1-server}"
CIS_DISABLE_PASSWORD_SSH="${CIS_DISABLE_PASSWORD_SSH:-true}"
CIS_APPLY_KERNEL_HARDENING="${CIS_APPLY_KERNEL_HARDENING:-true}"
EVIDENCE_DIR="/etc/pdgeek/template-hardening"
EVIDENCE_FILE="${EVIDENCE_DIR}/ubuntu-2404-cis.yml"

if [ "${ENABLE_CIS_BASELINE}" != "true" ]; then
  echo "==> CIS baseline disabled by ENABLE_CIS_BASELINE=${ENABLE_CIS_BASELINE}"
  exit 0
fi

echo "==> Applying ${CIS_PROFILE}"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
export NEEDRESTART_SUSPEND=1

NEEDRESTART_CONF="/etc/needrestart/conf.d/99-pdgeek-packer.conf"
if [ -d /etc/needrestart ]; then
  install -d -m 0755 /etc/needrestart/conf.d
  printf "%s\n" "\$nrconf{restart} = 'l';" >"${NEEDRESTART_CONF}"
fi
trap 'rm -f "${NEEDRESTART_CONF}"' EXIT

apt-get update
apt-get install -y --no-install-recommends \
  apparmor \
  apparmor-utils \
  auditd \
  audispd-plugins \
  libpam-pwquality \
  unattended-upgrades

systemctl enable apparmor
systemctl enable auditd
systemctl enable unattended-upgrades

echo "==> Configuring unattended security updates"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat >/etc/apt/apt.conf.d/51pdgeek-security-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
  "origin=Ubuntu,codename=${distro_codename},label=Ubuntu-Security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "==> Configuring audit rules"
cat >/etc/audit/rules.d/50-pdgeek-cis.rules <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock/ -p wa -k logins
EOF
augenrules --load || true

echo "==> Applying password quality defaults"
install -d -m 0755 /etc/security/pwquality.conf.d
cat >/etc/security/pwquality.conf.d/50-pdgeek-cis.conf <<'EOF'
minlen = 14
minclass = 4
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF

echo "==> Applying SSH hardening drop-in"
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/50-pdgeek-cis.conf <<EOF
PermitRootLogin no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 0
LoginGraceTime 60
Banner /etc/issue.net
PasswordAuthentication ${CIS_DISABLE_PASSWORD_SSH/true/no}
EOF
if [ "${CIS_DISABLE_PASSWORD_SSH}" != "true" ]; then
  sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-pdgeek-cis.conf
fi
ssh-keygen -q -N "" -t ed25519 -f /tmp/pdgeek_cis_sshd_test_key
sshd -t -h /tmp/pdgeek_cis_sshd_test_key
rm -f /tmp/pdgeek_cis_sshd_test_key /tmp/pdgeek_cis_sshd_test_key.pub

echo "Authorized access only. Activity may be monitored." >/etc/issue.net

if [ "${CIS_APPLY_KERNEL_HARDENING}" = "true" ]; then
  echo "==> Applying kernel and network sysctl hardening"
  cat >/etc/sysctl.d/60-pdgeek-cis.conf <<'EOF'
fs.suid_dumpable = 0
kernel.randomize_va_space = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
EOF
  sysctl --system
fi

echo "==> Disabling common non-server services when present"
for service in avahi-daemon cups isc-dhcp-server nfs-server rpcbind rsync smbd snmpd squid; do
  if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
    systemctl disable --now "${service}.service" || true
  fi
done

install -d -m 0755 "${EVIDENCE_DIR}"
cat >"${EVIDENCE_FILE}" <<EOF
profile: ${CIS_PROFILE}
template: tpl-ubuntu-2404
os: ubuntu-24.04
managed_by: packer
controls:
  apparmor: enabled
  auditd: enabled
  unattended_security_updates: enabled
  ssh_root_login: disabled
  ssh_password_authentication: $([ "${CIS_DISABLE_PASSWORD_SSH}" = "true" ] && echo "disabled" || echo "enabled")
  sysctl_kernel_hardening: $([ "${CIS_APPLY_KERNEL_HARDENING}" = "true" ] && echo "enabled" || echo "disabled")
  password_quality: enabled
  service_minimization: enabled
handoff:
  terraform: deploys VMs from this hardened template
  ansible: validates and finalizes guest/application state after clone
EOF
chmod 0644 "${EVIDENCE_FILE}"

echo "==> Removing SSH host keys for clone uniqueness"
rm -f /etc/ssh/ssh_host_*

echo "==> CIS baseline evidence written to ${EVIDENCE_FILE}"
