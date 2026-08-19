# Windows Server 2025 Template Validation

This is an in-progress feature branch path only. It is not part of the validated
mainline supported scope until a template has been built, cloned, and tested in a
customer-like vSphere lab.

## Source Notes

This scaffold follows the HashiCorp `vsphere-iso` builder behavior for
datastore/content-library `iso_paths`, generated floppy media, CD-ROM removal,
and remote ISO cache cleanup. It follows Microsoft Windows Setup guidance that
`Autounattend.xml` is automatically discovered from removable media in valid
search paths. It follows Broadcom guidance that Windows Server 2025 guest OS
selection requires compatible vSphere/ESXi support and VM hardware version 20+,
with Windows Server 2022 selected only as an explicit fallback when the 2025
option is unavailable. VMware Tools media must be preflighted because ESXi
productLocker paths can be absent or broken in real hosts.

## ISO Reference

Keep the Windows ISO outside git and reference it through an ignored variables
file:

```bash
cp packer/config/windows-server-2025.pkrvars.hcl.example \
  packer/config/windows-server-2025.pkrvars.hcl
```

For pipeline builds, upload the ISO to a vSphere datastore or content library
and set `windows_iso_path`:

```hcl
windows_iso_path = "[datastore1] iso/windows-server-2025.iso"
windows_iso_url = ""
windows_iso_checksum = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
```

For manual workstation builds, use a local file URL instead:

```hcl
windows_iso_path = ""
windows_iso_url = "file:///Users/levioister/Downloads/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO"
windows_iso_checksum = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
```

Do not set both `windows_iso_path` and `windows_iso_url` for a real build.

The local ISO was checked on 2026-08-19. Its SHA-256 checksum is
`cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4`.

The ISO contains these install images:

| Index | Image Name | Display Name |
|-------|------------|--------------|
| 1 | `Windows Server 2025 SERVERSTANDARDCORE` | Windows Server 2025 Standard |
| 2 | `Windows Server 2025 SERVERSTANDARD` | Windows Server 2025 Standard (Desktop Experience) |
| 3 | `Windows Server 2025 SERVERDATACENTERCORE` | Windows Server 2025 Datacenter |
| 4 | `Windows Server 2025 SERVERDATACENTER` | Windows Server 2025 Datacenter (Desktop Experience) |

## Syntax Validation

These checks do not require the Windows ISO:

```bash
make validate-windows-server-2025-template
```

The validator runs `packer fmt -check`, `packer init`, and
`packer validate -syntax-only` for the Windows Server 2025 build directory.

## Preflight

Run preflight before any real Packer build.

For the pipeline-safe datastore path:

```bash
export WINDOWS_SERVER_2025_ISO_VSPHERE_PATH="[datastore1] iso/windows-server-2025.iso"
export VSPHERE_SERVER="vcenter.lab.example.com"
export VSPHERE_USER="administrator@vsphere.local"
export VSPHERE_PASSWORD="..."
export ESXI_HOST="esx01.lab.example.com"
make preflight-windows-server-2025-template
```

For a manual workstation-only lab build:

```bash
export WINDOWS_SERVER_2025_LOCAL_ISO_PATH="/Users/levioister/Downloads/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO"
export ESXI_HOST="root@esx01.lab.example.com"
make preflight-windows-server-2025-template
```

The preflight script verifies the local ISO checksum when a local ISO is used,
verifies bracketed datastore ISO paths through PowerCLI when vSphere credentials
are present, checks the ESXi productLocker VMware Tools ISO over SSH when
`ESXI_HOST` is set, and queries the ESXi guest OS descriptor list when both
vSphere credentials and `ESXI_HOST` are set.

For content library ISO paths, verify the item before building:

```bash
govc library.ls "LibraryName/ItemName"
```

## Pipeline ISO Staging

Pipeline runners should consume a vSphere-hosted Windows ISO, not a workstation
`file://` path.

Datastore upload command trail:

```bash
export GOVC_URL="vcenter.lab.example.com"
export GOVC_USERNAME="administrator@vsphere.local"
export GOVC_PASSWORD="..."
export GOVC_INSECURE=1
export WINDOWS_SERVER_2025_LOCAL_ISO_PATH="/path/to/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO"

govc datastore.mkdir -ds "datastore1" iso
govc datastore.upload -ds "datastore1" \
  "$WINDOWS_SERVER_2025_LOCAL_ISO_PATH" \
  iso/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO
govc datastore.ls -ds "datastore1" \
  iso/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO
```

Content library staging can also work with Packer `iso_paths`, but validate the
library item path first because content library paths resolve differently from
datastore paths:

```bash
govc library.ls
govc library.ls "LibraryName/ItemName"
```

Do not run upload commands from shared automation until the datastore or content
library location, naming convention, retention owner, and overwrite policy are
approved.

## First Build

Before running Packer in a pipeline:

1. Upload the Windows Server 2025 ISO to a vSphere datastore or content library.
2. Set `windows_iso_path` to that datastore or content library path.
3. Verify `vmware_tools_iso_path` exists on the target ESXi host, or leave it
   empty and set `vmware_tools_installer_url` to an installer URL reachable
   from the guest.
4. Verify `guest_os_type` is accepted by the target vCenter/ESXi version.
5. Restrict `winrm_allowed_remote_addresses` to the Packer runner or build
   subnet.

After filling in vSphere settings and the ignored Windows variables file:

```bash
packer build -force \
  -var-file="packer/config/vsphere.pkrvars.hcl" \
  -var-file="packer/config/windows-server-2025.pkrvars.hcl" \
  packer/builds/windows/windows-server-2025/
```

The bootstrap `winrm_password` is injected into Autounattend XML during setup.
Use a temporary build password without XML-reserved characters (`<`, `>`, `&`),
then rotate credentials during post-clone configuration.

## Media And Artifact Cleanup

The Packer source sets `remove_cdrom = true`, so Packer removes CD-ROM devices
from the final template after a successful build. It also sets
`remote_cache_cleanup = true`, so temporary uploaded local ISO cache objects are
removed when manual `windows_iso_url` builds are used.

Pipeline runs should still check vCenter after failed builds. A failed Packer
run can stop before final cleanup, leaving a temporary VM with attached OS,
VMware Tools, or generated floppy media. Remove the failed
`tpl-windows-server-2025` VM before retrying, and confirm no generated removable
media or stale attached ISOs remain on the VM object.

Non-destructive inspection command trail:

```bash
govc vm.info "Templates/tpl-windows-server-2025"
govc device.ls -vm "Templates/tpl-windows-server-2025"
govc datastore.ls -ds "datastore1" iso/
```

Only after confirming a failed temporary VM is not a usable template, remove it
with an explicit command trail:

```bash
govc vm.destroy "Templates/tpl-windows-server-2025"
```

## Promotion Blockers

- Confirm vSphere presents the Windows Server 2025 guest OS type. If not, test
  the documented Windows Server 2022 fallback before promoting.
- Prove the pipeline build path with a datastore or content library Windows ISO
  path. The workstation-local `file://` path is for manual lab validation only.
- Preflight VMware Tools media. ESXi hosts can have broken or missing
  productLocker links, which makes `/usr/lib/vmware/isoimages/windows.iso`
  unavailable.
- Restrict WinRM HTTPS firewall source addresses to the Packer runner or build
  subnet.
- Build the template in vSphere, clone from it, and validate VMware Tools,
  network customization, WinRM post-clone behavior, sysprep state, and cleanup
  evidence.
- Confirm repeated failed and successful builds do not leave attached ISO media,
  generated removable media, stale CD-ROMs, or orphaned temporary VMs.
