$ErrorActionPreference = 'Stop'

$setup = Get-Volume |
    Where-Object { $_.DriveType -eq 'CD-ROM' -and $_.DriveLetter } |
    ForEach-Object { Join-Path ($_.DriveLetter + ':\') 'setup64.exe' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1

if (-not $setup) {
    throw 'VMware Tools setup64.exe was not found on attached CD-ROM media. Set vmware_tools_iso_path to a valid ESXi Windows tools ISO path.'
}

$logPath = 'C:\Windows\Temp\vmware-tools-install.log'
$arguments = '/S /v"/qn REBOOT=ReallySuppress" /l "' + $logPath + '"'
$process = Start-Process -FilePath $setup -ArgumentList $arguments -Wait -PassThru

if ($process.ExitCode -notin @(0, 3010)) {
    throw "VMware Tools installer exited with code $($process.ExitCode). See $logPath."
}
