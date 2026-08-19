$ErrorActionPreference = 'Stop'

$panther = 'C:\Windows\Panther'
New-Item -Path $panther -ItemType Directory -Force | Out-Null

Remove-ItemProperty `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' `
    -Name AutoAdminLogon, DefaultUserName, DefaultPassword, AutoLogonCount `
    -ErrorAction SilentlyContinue

& "$env:SystemRoot\System32\Sysprep\Sysprep.exe" /generalize /oobe /shutdown /mode:vm

if ($LASTEXITCODE -ne 0) {
    throw "Sysprep exited with code $LASTEXITCODE."
}
