# Windows Server 2025 Template Validation

This is an in-progress feature branch path only. It is not part of the validated
mainline supported scope until a template has been built, cloned, and tested in a
customer-like vSphere lab.

## Local ISO Reference

Keep the Windows ISO outside git and reference it through an ignored variables
file:

```bash
cp packer/config/windows-server-2025.pkrvars.hcl.example \
  packer/config/windows-server-2025.pkrvars.hcl
```

Set the local file URL in `packer/config/windows-server-2025.pkrvars.hcl`:

```hcl
windows_iso_url = "file:///Users/levioister/Downloads/SWDVD9_WinSrvSTDCORE2025_24H2.16_64Bit_English_DC_STD_MLF_RTMUpdJan26_X24-26760.ISO"
windows_iso_checksum = "sha256:cf96e924b4e7551169e09ef2a42d81340cdef11eaadf4bd4ac7bf1cdad5178a4"
```

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

After filling in vSphere settings, the ignored Windows variables file, and a
restricted `winrm_allowed_remote_addresses` value:

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
- Restrict WinRM HTTPS firewall source addresses to the Packer runner or build
  subnet.
- Build the template in vSphere, clone from it, and validate VMware Tools,
  network customization, WinRM post-clone behavior, sysprep state, and cleanup
  evidence.
