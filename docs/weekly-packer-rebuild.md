# Weekly Packer Template Rebuild

The operating rhythm is to rebuild VM templates weekly so Monday starts with current OS patches and fresh hardening evidence.

## GitLab Schedule

Create a GitLab pipeline schedule for this repo:

- Cron: `0 0 * * 5`
- Time zone: `America/Chicago`
- Description: `Friday midnight Packer template rebuild`
- Variables:
  - `PACKER_WEEKLY_REBUILD=true`

The schedule runs `.gitlab-ci.yml` job `templates:weekly-packer-rebuild`.

## Runner Requirements

The scheduled runner must have:

- Network access to vCenter and template networks
- Packer installed
- Ansible installed for Linux template hardening
- `packer/config/vsphere.pkrvars.hcl` available on the runner
- `packer/config/common.pkrvars.hcl` available on the runner

Do not commit real credentials or local var files. Store runner-side credentials in the approved secrets path and materialize the Packer var files during runner setup.

## Bootstrap Inputs

Linux templates:

- Ubuntu uses cloud-init autoinstall from `packer/builds/linux/ubuntu-2404/http/user-data`.
- RHEL/Rocky use kickstart from `packer/builds/linux/rhel-9/http/ks.cfg`.
- `open-vm-tools`, Python, and base utilities are installed during unattended OS setup.
- `build_username`, `build_password_hash`, and `ssh_public_key` come from `packer/config/common.pkrvars.hcl`.
- CIS hardening can disable SSH password auth, so `ssh_public_key` must be populated before hardened templates are built.

Windows templates:

- Packer generates `Autounattend.xml` from template variables and attaches it as floppy content.
- `build_password` sets the temporary Administrator password used by autologon and Packer WinRM.
- VMware Tools installs from `vmtools_iso_path` through `install-vmtools.ps1`.
- WinRM is enabled by `configure-winrm.ps1` so Packer can run post-install PowerShell provisioners.
- Sysprep generalizes and shuts down the VM before conversion to template.

## Default Template Set

The scheduled job rebuilds:

- `linux/ubuntu-2404`
- `linux/rhel-9`
- `linux/rocky-9`
- `windows/windows-server-2022`
- `windows/windows-server-2025`

Override `PACKER_TEMPLATE_PATHS` on a manual pipeline if only a subset should be rebuilt.

## Monday Readiness

After the schedule finishes, Monday work should start from:

1. Updated Packer templates in vCenter
2. Fresh CIS template evidence on Linux images
3. Terraform deployments cloning from the latest approved templates
4. Post-clone Ansible validation and application configuration
