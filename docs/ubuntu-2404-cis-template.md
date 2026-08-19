# Ubuntu 24.04 CIS Template Hook

The Ubuntu 24.04 template is the first hardened Linux base image for the higher-ed reference build.

## Build Pattern

The intended operating chain is:

1. Packer builds `tpl-ubuntu-2404` and applies the CIS-oriented template baseline.
2. Terraform deploys VMs from `tpl-ubuntu-2404` and applies ownership, billing, backup, lifecycle, and VMware Automation tags.
3. Ansible validates the cloned guest and finalizes app-specific configuration.

This keeps durable security controls in the base image while leaving workload-specific settings to Terraform and Ansible.

## CIS Hook

Packer runs `packer/builds/linux/ubuntu-2404/scripts/cis-baseline.sh` as the final guest-side provisioner.

The hook applies a narrow Ubuntu 24.04 Level 1 server baseline:

- AppArmor enabled
- auditd enabled with identity, sudo, and login evidence rules
- unattended Ubuntu security updates enabled
- SSH root login disabled
- SSH password authentication disabled by default
- password quality defaults staged through `libpam-pwquality`
- kernel and network sysctl hardening
- common non-server services disabled when present
- evidence written to `/etc/pdgeek/template-hardening/ubuntu-2404-cis.yml`

SSH hardening runs last because disabling password authentication can prevent later Packer provisioners from reconnecting when the build uses password-based SSH.

## Operator Variables

The Ubuntu template exposes these Packer variables:

```hcl
enable_cis_baseline        = true
cis_profile                = "cis-ubuntu-2404-level-1-server"
cis_disable_password_ssh   = true
cis_apply_kernel_hardening = true
```

Keep `ssh_public_key` populated before using the default `cis_disable_password_ssh = true`.

## Validate

```bash
make validate-ubuntu-2404-cis-template
```

This checks the Packer syntax, the hardening hook, required variables, and evidence handoff markers.
