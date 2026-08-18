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
