# Install VMware Tools from mounted CD
Write-Host "==> Installing VMware Tools..."

$installer = Get-ChildItem -Path D:\ -Filter "setup64.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($installer) {
    Start-Process -FilePath $installer.FullName -ArgumentList '/S /v "/qn REBOOT=R ADDLOCAL=ALL"' -Wait
    Write-Host "==> VMware Tools installed."
} else {
    Write-Host "==> VMware Tools installer not found on D:\ — skipping."
}
