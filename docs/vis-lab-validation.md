# VIS Lab Validation

The VCF Infrastructure Services (VIS) appliance is a lab and PoC target for validating this repo's automation and UX loops against realistic VCF 9.1 supporting services.

VIS is not the production reference architecture. It is a compact validation appliance that can supply lab services such as DNS, DHCP, NTP, OIDC, LDAP, SFTP backup, container registry, software depot, KMS, and shared TLS certificate handling. That makes it useful for proving that the service catalog and automation behave correctly before mapping the same workflows to enterprise services such as Infoblox, corporate identity, backup, PKI, and ITSM.

## What To Validate

- Provision a VM through the service catalog.
- Reserve or assign DNS/IP data through the lab DDI path.
- Configure guest OS baseline through Ansible.
- Deploy an application role such as nginx, PostgreSQL, IIS, SQL Server, Docker, or Active Directory.
- Post request status, evidence, logs, and resulting asset metadata back to the API/ITSM adapter.
- Capture browser UX evidence for request submission, approval, fulfillment progress, failure handling, and completed asset view.

## Validation Contract

Terraform owns the VM and platform-side objects needed after the VCF/VVF baseline exists.

Ansible owns guest configuration, hardening, application deployment, validation, and remediation.

VIS may satisfy lab-only infrastructure dependencies. Production mappings should use enterprise services:

| Lab service | Production equivalent |
|-------------|-----------------------|
| VIS DNS/DHCP | Infoblox or enterprise DDI |
| VIS OIDC/LDAP | Enterprise identity provider |
| VIS SFTP backup | Approved backup target |
| VIS registry | Enterprise container registry |
| VIS software depot | Enterprise software repository |
| VIS KMS | Approved enterprise KMS |
| VIS TLS | Enterprise PKI/certificate automation |

## First Test Scenarios

1. `vm-linux-basic`: request a Linux VM, assign DNS/IP, apply baseline, return asset evidence.
2. `app-nginx`: request a Linux VM and deploy nginx with a health check.
3. `db-postgresql`: request a PostgreSQL service with database/user creation and backup metadata.
4. `vm-windows-basic`: request a Windows VM, apply baseline, validate VMware Tools and Windows update posture.
5. `app-iis`: request a Windows IIS application and validate site availability.

Each scenario should produce machine-readable evidence, browser screenshots, browser console output, API logs, job logs, and final request state.
