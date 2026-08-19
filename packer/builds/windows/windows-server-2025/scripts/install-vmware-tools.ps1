$ErrorActionPreference = 'Stop'

$setup = Get-Volume |
    Where-Object { $_.DriveType -eq 'CD-ROM' -and $_.DriveLetter } |
    ForEach-Object { Join-Path ($_.DriveLetter + ':\') 'setup64.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

$installerUrl = $env:VMWARE_TOOLS_INSTALLER_URL
if (-not $setup -and -not [string]::IsNullOrWhiteSpace($installerUrl)) {
    $setup = 'C:\Windows\Temp\vmware-tools-setup.exe'
    Invoke-WebRequest -Uri $installerUrl -OutFile $setup
}

if (-not $setup) {
    throw 'VMware Tools setup64.exe was not found on attached CD-ROM media, and VMWARE_TOOLS_INSTALLER_URL was not set. Preflight productLocker before setting vmware_tools_iso_path, or provide vmware_tools_installer_url.'
}

$logPath = 'C:\Windows\Temp\vmware-tools-install.log'
$arguments = '/S /v"/qn REBOOT=ReallySuppress" /l "' + $logPath + '"'
$process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru

if ($process.ExitCode -notin @(0, 3010)) {
    throw "VMware Tools installer exited with code $($process.ExitCode). See $logPath."
}
