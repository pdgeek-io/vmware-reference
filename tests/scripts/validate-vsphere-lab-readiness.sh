#!/usr/bin/env bash
# Validate the minimal vSphere 8 lab prerequisites for Day-2 API work.
set -euo pipefail

CONFIG_FILE="${VSPHERE_LAB_CONFIG:-config/vsphere-lab-readiness.env}"
EXAMPLE_CONFIG_FILE="config/vsphere-lab-readiness.env.example"

PASS=0
FAIL=0
SKIP=0

ENV_VSPHERE_DNS_SERVER="${VSPHERE_DNS_SERVER:-}"
ENV_VSPHERE_REQUIRED_FQDNS="${VSPHERE_REQUIRED_FQDNS:-}"
ENV_VSPHERE_NTP_SERVER="${VSPHERE_NTP_SERVER:-}"
ENV_VSPHERE_NTP_REQUIRED="${VSPHERE_NTP_REQUIRED:-}"
ENV_VCENTER_URL="${VCENTER_URL:-}"
ENV_VCENTER_TLS_VERIFY="${VCENTER_TLS_VERIFY:-}"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
elif [[ -f "$EXAMPLE_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$EXAMPLE_CONFIG_FILE"
fi

VSPHERE_DNS_SERVER="${ENV_VSPHERE_DNS_SERVER:-${VSPHERE_DNS_SERVER:-}}"
VSPHERE_REQUIRED_FQDNS="${ENV_VSPHERE_REQUIRED_FQDNS:-${VSPHERE_REQUIRED_FQDNS:-}}"
VSPHERE_NTP_SERVER="${ENV_VSPHERE_NTP_SERVER:-${VSPHERE_NTP_SERVER:-}}"
VSPHERE_NTP_REQUIRED="${ENV_VSPHERE_NTP_REQUIRED:-${VSPHERE_NTP_REQUIRED:-false}}"
VCENTER_URL="${ENV_VCENTER_URL:-${VCENTER_URL:-}}"
VCENTER_TLS_VERIFY="${ENV_VCENTER_TLS_VERIFY:-${VCENTER_TLS_VERIFY:-false}}"

pass() {
    echo "  [PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

skip() {
    echo "  [SKIP] $1"
    SKIP=$((SKIP + 1))
}

need_command() {
    command -v "$1" >/dev/null 2>&1
}

run_with_timeout() {
    local seconds="$1"
    shift

    if need_command timeout; then
        timeout "$seconds" "$@"
        return
    fi

    if need_command gtimeout; then
        gtimeout "$seconds" "$@"
        return
    fi

    if need_command python3; then
        python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

seconds = float(sys.argv[1])
command = sys.argv[2:]

try:
    completed = subprocess.run(command, timeout=seconds)
except subprocess.TimeoutExpired:
    raise SystemExit(124)

raise SystemExit(completed.returncode)
PY
        return
    fi

    echo "No timeout runner found (timeout, gtimeout, or python3)" >&2
    return 124
}

check_http() {
    local name="$1"
    local url="$2"
    local curl_args=(--fail --silent --show-error --location --connect-timeout 5 --max-time 10 --output /dev/null)
    local address
    local url_host
    local url_port

    if [[ -z "$url" ]]; then
        skip "$name HTTP endpoint not configured"
        return
    fi

    if [[ "$VCENTER_TLS_VERIFY" != "true" ]]; then
        curl_args+=(--insecure)
    fi

    if [[ -n "$VSPHERE_DNS_SERVER" ]] && need_command python3; then
        read -r url_host url_port < <(python3 - "$url" <<'PY'
from urllib.parse import urlparse
import sys

parsed = urlparse(sys.argv[1])
host = parsed.hostname or ""
port = parsed.port or (443 if parsed.scheme == "https" else 80)
print(host, port)
PY
)
        if [[ -n "$url_host" && ! "$url_host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            address="$(resolve_name "$url_host" | head -n 1 || true)"
            if [[ -n "$address" ]]; then
                curl_args+=(--resolve "${url_host}:${url_port}:${address}")
            fi
        fi
    fi

    if run_with_timeout 12 curl "${curl_args[@]}" "$url"; then
        pass "$name HTTP reachable: $url"
    else
        fail "$name HTTP unreachable: $url"
    fi
}

resolve_name() {
    local fqdn="$1"

    if need_command dig; then
        if [[ -n "$VSPHERE_DNS_SERVER" ]]; then
            run_with_timeout 5 dig +short +time=3 +tries=1 @"$VSPHERE_DNS_SERVER" "$fqdn" A 2>/dev/null | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/'
        else
            run_with_timeout 5 dig +short +time=3 +tries=1 "$fqdn" A 2>/dev/null | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/'
        fi
        return
    fi

    if need_command getent; then
        run_with_timeout 5 getent ahostsv4 "$fqdn" | awk '{print $1}' | sort -u
        return
    fi

    if need_command nslookup; then
        if [[ -n "$VSPHERE_DNS_SERVER" ]]; then
            run_with_timeout 5 nslookup "$fqdn" "$VSPHERE_DNS_SERVER" 2>/dev/null | awk '/^Address: / {print $2}'
        else
            run_with_timeout 5 nslookup "$fqdn" 2>/dev/null | awk '/^Address: / {print $2}'
        fi
        return
    fi

    return 1
}

check_dns() {
    local fqdn
    local addresses

    if [[ -z "$VSPHERE_REQUIRED_FQDNS" ]]; then
        fail "No VSPHERE_REQUIRED_FQDNS configured"
        return
    fi

    if ! need_command dig && ! need_command getent && ! need_command nslookup; then
        fail "No DNS lookup command found (dig, getent, or nslookup)"
        return
    fi

    for fqdn in $VSPHERE_REQUIRED_FQDNS; do
        addresses="$(resolve_name "$fqdn" | tr '\n' ' ' | xargs || true)"
        if [[ -n "$addresses" ]]; then
            pass "DNS resolves $fqdn -> $addresses"
        else
            fail "DNS record missing or unresolved: $fqdn"
        fi
    done
}

check_ntp_reachability() {
    local server="$1"

    if [[ -z "$server" ]]; then
        skip "VSPHERE_NTP_SERVER not configured"
        return
    fi

    if need_command sntp; then
        if run_with_timeout 8 sntp -t 5 "$server" >/dev/null 2>&1; then
            pass "NTP reachable: $server"
        else
            ntp_probe_unreachable "sntp" "$server"
        fi
        return
    fi

    if need_command ntpdate; then
        if run_with_timeout 8 ntpdate -q "$server" >/dev/null 2>&1; then
            pass "NTP reachable: $server"
        else
            ntp_probe_unreachable "ntpdate" "$server"
        fi
        return
    fi

    if need_command python3; then
        if run_with_timeout 8 python3 -c '
import socket
import struct
import sys

server = sys.argv[1]
packet = b"\x1b" + 47 * b"\0"

with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.settimeout(5)
    sock.connect((server, 123))
    sock.sendall(packet)
    data = sock.recv(48)

if len(data) < 48:
    raise SystemExit(1)

struct.unpack("!12I", data)
' "$server" >/dev/null 2>&1
        then
            pass "NTP reachable: $server"
        else
            ntp_probe_unreachable "python UDP probe" "$server"
        fi
        return
    fi

    skip "No NTP probe command found (sntp, ntpdate, or python3)"
}

ntp_probe_unreachable() {
    local probe="$1"
    local server="$2"

    if [[ "$VSPHERE_NTP_REQUIRED" == "true" ]]; then
        fail "NTP unreachable or timed out via $probe: $server"
    else
        skip "NTP unreachable from this runner via $probe: $server"
    fi
}

check_ntp_sync_source() {
    local source=""

    if need_command chronyc; then
        source="$(run_with_timeout 5 chronyc sources -n 2>/dev/null | awk '/^\^\*/ {print $2; exit}' || true)"
    elif need_command ntpq; then
        source="$(run_with_timeout 5 ntpq -pn 2>/dev/null | awk '/^\*/ {print $1; exit}' | sed 's/^\*//' || true)"
    elif need_command timedatectl; then
        if run_with_timeout 5 timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qi '^yes$'; then
            source="systemd-timesyncd"
        fi
    fi

    if [[ -n "$source" ]]; then
        pass "Local NTP sync source active: $source"
    else
        skip "Local NTP sync source not detectable from this workstation"
    fi
}

echo "==> vSphere lab readiness validation"
echo "    Config: $CONFIG_FILE"
if [[ ! -f "$CONFIG_FILE" && -f "$EXAMPLE_CONFIG_FILE" ]]; then
    echo "    Using example defaults: $EXAMPLE_CONFIG_FILE"
fi
echo ""

echo "-- vSphere DNS --"
check_dns

echo ""
echo "-- NTP --"
check_ntp_reachability "$VSPHERE_NTP_SERVER"
check_ntp_sync_source

echo ""
echo "-- Optional vCenter API --"
check_http "vCenter" "$VCENTER_URL"

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
exit "$FAIL"
