#!/bin/bash
# Placeholder cleanup for security, EDR, monitoring, backup, and management
# agents in reusable Linux templates.
#
# Add customer/vendor-specific reset commands here when a tool is introduced.
# This script is safe before those tools exist; it records what it found and
# avoids baking registered agent identity into the golden image.
set -euo pipefail

echo "==> Cleaning Linux security/management agent template state..."

evidence_dir="/etc/pdgeek/template-hardening"
evidence_file="${evidence_dir}/linux-agent-cleanup.json"
mkdir -p "${evidence_dir}"

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

cat >"${tmp_file}" <<'JSON'
[]
JSON

record_agent() {
  local name="$1"
  local status="$2"
  local notes="$3"

  python3 - "$tmp_file" "$name" "$status" "$notes" <<'PY'
import json
import sys

path, name, status, notes = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
data.append({"name": name, "cleanupStatus": status, "notes": notes})
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
PY
}

disable_service_if_present() {
  local service="$1"
  if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
    systemctl disable --now "${service}.service" >/dev/null 2>&1 || true
    return 0
  fi
  return 1
}

found="not-present"
if disable_service_if_present falcon-sensor || [ -d /opt/CrowdStrike ] || [ -d /var/lib/crowdstrike ]; then
  found="placeholder-required"
fi
record_agent "CrowdStrike Falcon" "${found}" "Add vendor-supported AID/CID reset or uninstall/reinstall workflow here."

found="not-present"
if disable_service_if_present sentinelone || disable_service_if_present sentineld || [ -d /opt/sentinelone ]; then
  found="placeholder-required"
fi
record_agent "SentinelOne" "${found}" "Add vendor-supported agent identity reset or uninstall workflow here."

found="not-present"
if disable_service_if_present taniumclient || [ -d /opt/Tanium ]; then
  found="placeholder-required"
fi
record_agent "Tanium" "${found}" "Clear registration/client identity only through approved Tanium procedure."

found="not-present"
if disable_service_if_present splunkforwarder || [ -d /opt/splunkforwarder ]; then
  found="placeholder-required"
fi
record_agent "Splunk Universal Forwarder" "${found}" "Clear deployment client identity and fishbucket only when required by design."

found="not-present"
if disable_service_if_present veeamservice || [ -d /opt/veeam ]; then
  found="placeholder-required"
fi
record_agent "Veeam" "${found}" "Clear job/session/cache state if the agent is intentionally included."

cp "${tmp_file}" "${evidence_file}"
chmod 0644 "${evidence_file}"
echo "==> Agent cleanup evidence written to ${evidence_file}"
