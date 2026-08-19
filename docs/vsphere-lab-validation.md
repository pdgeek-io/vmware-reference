# vSphere Lab Validation

The current lab phase validates the smallest useful VMware API target for this repo: ESXi hosts plus vCenter/VCSA 8.

This validation path does not stage, deploy, or inspect VMware installation media. It only checks that already-provided lab services are ready for the higher-ed baseline workflow.

## What To Validate

- Validate smallest vSphere API lab readiness with `make validate-vsphere-lab`.
- Build or select the Ubuntu 24.04 template.
- Create the baseline vSphere tags.
- Clone the higher-ed Linux VM through `terraform/stacks/03-workloads`.
- Render Terraform output into an Ansible inventory.
- Configure and validate the guest with `ansible/playbooks/higher-ed-linux-baseline.yml`.

## Smallest vSphere Lab Readiness

Use the readiness check before running automation against the ESXi + vCenter lab. It validates the supporting services this repo consumes; it does not deploy ESXi, vCenter, VCF, SDDC Manager, NSX, or VIS.

1. Copy `config/vsphere-lab-readiness.env.example` to `config/vsphere-lab-readiness.env` for persistent lab-specific values. Without that file, the validator uses example defaults.
2. Set the DNS server, required vCenter/ESXi FQDNs, NTP server, and optional vCenter URL for the lab.
3. Run:

   ```bash
   make validate-vsphere-lab
   ```

The validator checks:

- A records for each FQDN in `VSPHERE_REQUIRED_FQDNS`.
- NTP reachability for `VSPHERE_NTP_SERVER` when configured. Set `VSPHERE_NTP_REQUIRED=true` only when the runner is on a network path that must reach lab NTP.
- The local workstation's detectable NTP sync source when `chronyc`, `ntpq`, or `timedatectl` is available.
- vCenter HTTPS/API reachability when `VCENTER_URL` is configured. If `VSPHERE_DNS_SERVER` is set, the validator resolves the vCenter URL hostname through lab DNS for the curl check. `VCENTER_TLS_VERIFY=false` allows the normal lab self-signed certificate phase.

VCF, SDDC Manager, VIS, NSX, storage, app, portal, and ITSM checks are intentionally out of this phase.

## Validation Contract

Terraform owns the VM and platform-side objects needed after the vSphere baseline exists.

Ansible owns guest configuration, metadata evidence, and baseline validation.

## First Test Scenarios

1. `vsphere-lab-ready`: DNS, optional NTP, and optional vCenter HTTPS/API checks pass.
2. `higher-ed-small-linux`: Terraform creates the VM, writes inventory data, and Ansible validates DNS plus TCP port 22.

Additional app, Windows, database, storage, portal, and ITSM scenarios are deferred.
