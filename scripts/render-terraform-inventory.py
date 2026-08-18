#!/usr/bin/env python3
"""Render Terraform vm_inventory output as a minimal Ansible inventory.

Usage:
    terraform -chdir=terraform/stacks/03-workloads output -json vm_inventory \
      | python3 scripts/render-terraform-inventory.py --group higher_ed_linux

The workload stack is the source of truth for VM metadata. This script only
translates that output into host variables Ansible can consume.
"""

from __future__ import annotations

import argparse
import json
import sys

import yaml


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", default="terraform_vms")
    parser.add_argument("--user", default=None)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        inventory = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(f"Invalid Terraform inventory JSON: {exc}", file=sys.stderr)
        return 2

    hosts = {}
    for name, vm in sorted(inventory.items()):
        ip_address = vm.get("ip_address")
        if not ip_address:
            print(f"Skipping {name}: missing ip_address", file=sys.stderr)
            continue

        validation = vm.get("validation") or {}
        chargeback = vm.get("chargeback") or {}

        hostvars = {
            "ansible_host": ip_address,
            "vm_fqdn": vm.get("fqdn", ""),
            "vm_template": vm.get("template", ""),
            "vm_folder": vm.get("folder", ""),
            "vm_tags": vm.get("tags", []),
            "chargeback": chargeback,
            "department": chargeback.get("department", ""),
            "cost_center": chargeback.get("cost_center", ""),
            "project": chargeback.get("project", ""),
            "environment": chargeback.get("environment", ""),
            "application": chargeback.get("application", ""),
            "app_owner": chargeback.get("app_owner", chargeback.get("owner", "")),
            "technical_owner": chargeback.get("technical_owner", ""),
            "service_tier": chargeback.get("service_tier", ""),
            "backup_policy": chargeback.get("backup_policy", ""),
            "billing_model": chargeback.get("billing_model", ""),
            "data_classification": chargeback.get("data_classification", ""),
            "lifecycle": chargeback.get("lifecycle", ""),
            "tcp_validation_ports": validation.get("tcp_ports", [22]),
        }
        if args.user:
            hostvars["ansible_user"] = args.user
        hosts[name] = hostvars

    yaml.safe_dump(
        {"all": {"children": {args.group: {"hosts": hosts}}}},
        sys.stdout,
        sort_keys=False,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
