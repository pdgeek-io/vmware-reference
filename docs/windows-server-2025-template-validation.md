# Windows Server 2025 Template Validation

This is an in-progress feature branch path only. It is not part of the validated
mainline supported scope until a template has been built, cloned, and tested in a
customer-like vSphere lab.

## ISO Reference

Keep the Windows ISO outside git and reference it through an ignored variables
file:

```bash
cp packer/config/windows-server-2025.pkrvars.hcl.example \
  packer/config/windows-server-2025.pkrvars.hcl
```

For pipeline builds, upload the ISO to a vSphere datastore or content library
and set `windows_iso_paths`:

```hcl
windows_iso_paths = [
  "[datastore1] iso/windows-server-2025.iso",
]
windows_iso_url = ""
windows_iso_checksum = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
```

For manual workstation builds, use a local file URL instead:

```hcl
windows_iso_paths = []
windows_iso_url = "file:///Users/levioister/Downloads/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO"
windows_iso_checksum = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
```

Do not set both `windows_iso_paths` and `windows_iso_url` for a real build.

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

## First Build

Before running Packer in a pipeline:

1. Upload the Windows Server 2025 ISO to a vSphere datastore or content library.
2. Set `windows_iso_paths` to that datastore or content library path.
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
