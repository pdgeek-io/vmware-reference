# vSphere Lab Validation

The current lab phase validates the smallest useful VMware API target for this repo: ESXi hosts plus vCenter/VCSA 8. VIS and full VCF 9.1 validation are deferred until official media and entitlement are available.

This validation path does not stage, deploy, or inspect VMware installation media. It only checks that already-provided lab services are ready for Day-2 automation development.

## What To Validate

- Validate smallest vSphere API lab readiness with `make validate-vsphere-lab`.
- Provision a VM through the service catalog.
- Reserve or assign DNS/IP data through the lab DDI path.
- Configure guest OS baseline through Ansible.
- Deploy an application role such as nginx, PostgreSQL, IIS, SQL Server, Docker, or Active Directory.
- Post request status, evidence, logs, and resulting asset metadata back to the API/ITSM adapter.
- Capture browser UX evidence for request submission, approval, fulfillment progress, failure handling, and completed asset view.

## Smallest vSphere Lab Readiness

Use the readiness check before running Day-2 automation against the ESXi + vCenter lab. It validates the supporting services this repo consumes; it does not deploy ESXi, vCenter, VCF, SDDC Manager, NSX, or VIS.

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

VCF, SDDC Manager, VIS, and NSX checks are intentionally out of this phase. This repo stays focused on Day-2 automation validation against the smallest legitimate vSphere surface first.

## Validation Contract

Terraform owns the VM and platform-side objects needed after the VCF/VVF baseline exists.

Ansible owns guest configuration, hardening, application deployment, validation, and remediation.

Lab-only infrastructure dependencies should map cleanly to production services:

| Lab service | Production equivalent |
|-------------|-----------------------|
| Lab DNS/DHCP | Infoblox or enterprise DDI |
| Lab identity | Enterprise identity provider |
| Lab backup target | Approved backup target |
| Lab registry | Enterprise container registry |
| Lab software repository | Enterprise software repository |
| Lab KMS | Approved enterprise KMS |
| Lab TLS | Enterprise PKI/certificate automation |

## First Test Scenarios

1. `vm-linux-basic`: request a Linux VM, assign DNS/IP, apply baseline, return asset evidence.
2. `app-nginx`: request a Linux VM and deploy nginx with a health check.
3. `db-postgresql`: request a PostgreSQL service with database/user creation and backup metadata.
4. `vm-windows-basic`: request a Windows VM, apply baseline, validate VMware Tools and Windows update posture.
5. `app-iis`: request a Windows IIS application and validate site availability.

Each scenario should produce machine-readable evidence, browser screenshots, browser console output, API logs, job logs, and final request state.
