$ErrorActionPreference = 'Stop'

$certificate = New-SelfSignedCertificate `
    -DnsName $env:COMPUTERNAME `
    -CertStoreLocation 'Cert:\LocalMachine\My' `
    -KeyLength 2048 `
    -NotAfter (Get-Date).AddYears(2)

winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Basic="false"}'
winrm set winrm/config/service/auth '@{NTLM="true"}'

$selector = "@{Address='*';Transport='HTTPS'}"
$existingListener = winrm enumerate winrm/config/listener | Select-String 'Transport = HTTPS' -Quiet
if ($existingListener) {
    winrm delete "winrm/config/Listener?Address=*+Transport=HTTPS"
}

winrm create "winrm/config/Listener?$selector" "@{Hostname='$env:COMPUTERNAME';CertificateThumbprint='$($certificate.Thumbprint)'}"
Set-Item -Path WSMan:\localhost\Service\CertificateThumbprint -Value $certificate.Thumbprint

$remoteAddress = '${winrm_allowed_remote_addresses}'
if ([string]::IsNullOrWhiteSpace($remoteAddress)) {
    $remoteAddress = 'Any'
}

Remove-NetFirewallRule -DisplayName 'Packer WinRM HTTPS' -ErrorAction SilentlyContinue
New-NetFirewallRule `
    -DisplayName 'Packer WinRM HTTPS' `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 5986 `
    -RemoteAddress $remoteAddress `
    -Profile Any

Set-Service -Name WinRM -StartupType Automatic
Restart-Service -Name WinRM
