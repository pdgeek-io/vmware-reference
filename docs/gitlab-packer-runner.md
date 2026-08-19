# GitLab Packer Runner

Packer template builds run in GitLab, not on an operator workstation.

## Runner Purpose

This runner builds vSphere VM templates for the VMware Automation service catalog. It needs access to vCenter, template networks, ISO datastores, and runner-side Packer variables, so it must be dedicated and tagged.

Required tags:

- `packer`
- `vsphere`
- `vmware-automation`

The `.gitlab-ci.yml` template build job declares all three tags. Generic shared runners must not build templates.

## Host Requirements

Install on a host with routed access to the vSphere lab or production vCenter:

- GitLab Runner
- Packer
- Ansible
- PowerShell, for Windows template validation/build helpers when needed
- VMware/vCenter network reachability
- Access to OS ISO datastore paths referenced by Packer

## Registration

Register the runner as a project runner for `levi-knox/vmware-reference` using the GitLab runner authentication token from the GitLab UI or API. Do not commit the token.

Example shape:

```bash
gitlab-runner register \
  --url "https://gitlab.pdgeek.com" \
  --token "$GITLAB_RUNNER_AUTH_TOKEN" \
  --executor "shell" \
  --description "vmware-reference-packer-vsphere" \
  --tag-list "packer,vsphere,vmware-automation" \
  --run-untagged="false" \
  --locked="true"
```

Use the shell executor unless the runner host has a container runtime with nested virtualization/networking access proven for vSphere ISO builds.

## CI Variables

Create protected GitLab CI/CD variables for the project:

- `PACKER_WEEKLY_REBUILD=true` on the schedule
- `PACKER_VSPHERE_PKRVARS_FILE` as a file variable containing `packer/config/vsphere.pkrvars.hcl`
- `PACKER_COMMON_PKRVARS_FILE` as a file variable containing `packer/config/common.pkrvars.hcl`

Text fallbacks are supported by the CI job:

- `PACKER_VSPHERE_PKRVARS_HCL`
- `PACKER_COMMON_PKRVARS_HCL`

Prefer file variables for multi-line HCL.

## First Build

After the runner is registered and variables are present:

1. Start with a manual pipeline on the MR branch.
2. Set `PACKER_WEEKLY_REBUILD=true`.
3. Set `PACKER_TEMPLATE_PATHS=linux/ubuntu-2404`.
4. Confirm `templates:weekly-packer-rebuild` lands on the dedicated runner.
5. Review the resulting `tpl-ubuntu-2404` template and hardening evidence.

Only expand to all templates after Ubuntu proves clean.
