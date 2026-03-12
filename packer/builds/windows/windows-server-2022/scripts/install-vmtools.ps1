# Install VMware Tools from mounted CD-ROM
# Scans all CD-ROM drives since the drive letter varies with EFI partition layouts
Write-Host "==> Installing VMware Tools..."

$installer = $null
$cdDrives = Get-Volume | Where-Object { $_.DriveType -eq 'CD-ROM' } | Select-Object -ExpandProperty DriveLetter
foreach ($letter in $cdDrives) {
    $found = Get-ChildItem -Path "${letter}:\" -Filter "setup64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $installer = $found
        Write-Host "==> Found VMware Tools installer on ${letter}:\"
        break
    }
}

if ($installer) {
    Start-Process -FilePath $installer.FullName -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
    Write-Host "==> VMware Tools installed."
} else {
    Write-Host "==> WARNING: VMware Tools installer not found on any CD-ROM drive."
    Write-Host "    Verify the VMware Tools ISO is mounted (vmtools_iso_path variable)."
}
