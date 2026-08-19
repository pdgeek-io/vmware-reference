# Security Policy

## Supported Scope

Security review applies to the supported baseline on the default branch:

- Ubuntu 24.04 Packer template
- vSphere VM Terraform module and workload stack
- higher-ed Linux Ansible baseline
- vSphere tag setup script
- validation scripts

Unimplemented or removed roadmap capabilities are not supported security surfaces.

## Reporting A Vulnerability

Report vulnerabilities through GitHub private vulnerability reporting when available for this repository. If private reporting is not available, open a GitHub Security Advisory draft or contact the repository owner through the organization's published support channel.

Do not include secrets, customer data, exploit payloads against third-party systems, or sensitive infrastructure details in public issues.

## Security Expectations

- No secrets, credentials, VM media, generated inventories, Terraform state, or customer data in git.
- Infrastructure changes must include validation evidence.
- Guest hardening changes must document the control intent and operational impact.
- Any new customer-facing workflow must include local validation, CI validation, and operator documentation before merge.

