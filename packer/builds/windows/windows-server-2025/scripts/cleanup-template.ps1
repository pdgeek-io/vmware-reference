$ErrorActionPreference = 'Stop'

$evidenceDirectory = 'C:\ProgramData\PDGeek\TemplateBuild'
New-Item -Path $evidenceDirectory -ItemType Directory -Force | Out-Null

Get-ChildItem -Path 'C:\Windows\Temp' -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

wevtutil el | ForEach-Object {
    wevtutil cl $_ 2>$null
}

Set-Content -Path (Join-Path $evidenceDirectory 'windows-server-2025-template.yml') -Value @(
    'os: windows-server-2025'
    'status: feature-branch-scaffold'
    'vmware_tools: installed-by-packer-hook'
    'winrm: https-ntlm-self-signed-build-listener'
    'cleanup: template-cleanup-hook-ran'
)
