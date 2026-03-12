# Configure WinRM for Packer communication
Write-Host "==> Configuring WinRM..."

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
winrm quickconfig -q
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

Set-Service -Name winrm -StartupType Automatic
Restart-Service winrm

Write-Host "==> WinRM configured."
