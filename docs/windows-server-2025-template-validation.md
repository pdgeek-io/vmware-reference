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
```

Set `windows_iso_checksum` to the SHA-256 digest of the local ISO before a real
build.

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

- Confirm the exact `windows_image_name` exposed by the provided ISO.
- Confirm vSphere presents the Windows Server 2025 guest OS type. If not, test
  the documented Windows Server 2022 fallback before promoting.
- Replace `windows_iso_checksum = "none"` or placeholder values with a verified
  SHA-256 checksum in local build configuration.
- Restrict WinRM HTTPS firewall source addresses to the Packer runner or build
  subnet.
- Build the template in vSphere, clone from it, and validate VMware Tools,
  network customization, WinRM post-clone behavior, sysprep state, and cleanup
  evidence.
