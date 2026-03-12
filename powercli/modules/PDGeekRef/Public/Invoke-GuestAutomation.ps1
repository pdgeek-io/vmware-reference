function Invoke-GuestAutomation {
    <#
    .SYNOPSIS
        Run scripts and commands inside guest VMs via VMware Tools — no SSH/WinRM needed.
    .DESCRIPTION
        Uses VMware Tools guest operations (Invoke-VMScript) to execute commands
        inside the guest OS. Supports running inline scripts, script files, and
        common automation tasks (package install, service management, file deployment).
    .EXAMPLE
        Invoke-GuestAutomation -VMName "web-01" -Script "hostname && uptime"
    .EXAMPLE
        Invoke-GuestAutomation -VMName "web-01" -Action InstallPackage -PackageName "nginx"
    .EXAMPLE
        Invoke-GuestAutomation -VMName "db-01" -ScriptFile "./scripts/configure-postgres.sh"
    .EXAMPLE
        Invoke-GuestAutomation -VMName "win-01" -Script "Get-Service | Where Running" -ScriptType PowerShell
    #>
    [CmdletBinding(DefaultParameterSetName = "InlineScript")]
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory, ParameterSetName = "InlineScript")]
        [string]$Script,

        [Parameter(Mandatory, ParameterSetName = "ScriptFile")]
        [string]$ScriptFile,

        [Parameter(Mandatory, ParameterSetName = "Action")]
        [ValidateSet("InstallPackage", "StartService", "StopService", "RestartService", "UpdateOS", "CheckDisk", "GetSystemInfo")]
        [string]$Action,

        [Parameter(ParameterSetName = "Action")]
        [string]$PackageName,

        [Parameter(ParameterSetName = "Action")]
        [string]$ServiceName,

        [Parameter()]
        [ValidateSet("Bash", "PowerShell")]
        [string]$ScriptType = "Bash",

        [Parameter()]
        [PSCredential]$GuestCredential
    )

    Connect-RefEnvironment

    $vm = Get-VM -Name $VMName -ErrorAction Stop

    # Validate VM is powered on and tools are running
    if ($vm.PowerState -ne "PoweredOn") {
        throw "VM '$VMName' is not powered on."
    }

    $toolsStatus = $vm.ExtensionData.Guest.ToolsRunningStatus
    if ($toolsStatus -ne "guestToolsRunning") {
        throw "VMware Tools is not running on '$VMName' (status: $toolsStatus)"
    }

    # Get guest credentials
    if (-not $GuestCredential) {
        $GuestCredential = Get-Credential -Message "Enter guest OS credentials for $VMName"
    }

    # Determine script to run
    $scriptContent = switch ($PSCmdlet.ParameterSetName) {
        "InlineScript" { $Script }
        "ScriptFile" {
            if (-not (Test-Path $ScriptFile)) { throw "Script file not found: $ScriptFile" }
            Get-Content $ScriptFile -Raw
        }
        "Action" {
            switch ($Action) {
                "InstallPackage" {
                    if (-not $PackageName) { throw "-PackageName is required for InstallPackage" }
                    if ($ScriptType -eq "Bash") {
                        "if command -v apt-get &>/dev/null; then apt-get update && apt-get install -y $PackageName; elif command -v dnf &>/dev/null; then dnf install -y $PackageName; elif command -v yum &>/dev/null; then yum install -y $PackageName; fi"
                    } else {
                        "Install-WindowsFeature -Name $PackageName -IncludeManagementTools"
                    }
                }
                "StartService" {
                    if (-not $ServiceName) { throw "-ServiceName is required" }
                    if ($ScriptType -eq "Bash") { "systemctl start $ServiceName && systemctl status $ServiceName" }
                    else { "Start-Service '$ServiceName'; Get-Service '$ServiceName'" }
                }
                "StopService" {
                    if (-not $ServiceName) { throw "-ServiceName is required" }
                    if ($ScriptType -eq "Bash") { "systemctl stop $ServiceName && systemctl status $ServiceName" }
                    else { "Stop-Service '$ServiceName'; Get-Service '$ServiceName'" }
                }
                "RestartService" {
                    if (-not $ServiceName) { throw "-ServiceName is required" }
                    if ($ScriptType -eq "Bash") { "systemctl restart $ServiceName && systemctl status $ServiceName" }
                    else { "Restart-Service '$ServiceName'; Get-Service '$ServiceName'" }
                }
                "UpdateOS" {
                    if ($ScriptType -eq "Bash") {
                        "if command -v apt-get &>/dev/null; then apt-get update && apt-get upgrade -y; elif command -v dnf &>/dev/null; then dnf upgrade -y; fi"
                    } else {
                        "Install-Module PSWindowsUpdate -Force -Confirm:`$false; Get-WindowsUpdate -Install -AcceptAll -AutoReboot"
                    }
                }
                "CheckDisk" {
                    if ($ScriptType -eq "Bash") { "df -h && echo '---' && lsblk" }
                    else { "Get-Volume | Format-Table -AutoSize" }
                }
                "GetSystemInfo" {
                    if ($ScriptType -eq "Bash") {
                        "echo '=== Hostname ===' && hostname -f && echo '=== OS ===' && cat /etc/os-release | head -5 && echo '=== CPU ===' && nproc && echo '=== Memory ===' && free -h && echo '=== Disk ===' && df -h / && echo '=== VMware Tools ===' && vmware-toolbox-cmd -v"
                    } else {
                        "Write-Host '=== System ===' ; Get-ComputerInfo | Select-Object CsName,OsName,OsArchitecture,CsTotalPhysicalMemory | Format-List ; Write-Host '=== Disk ===' ; Get-Volume | Format-Table"
                    }
                }
            }
        }
    }

    Write-Host "`n=== Guest Automation: $VMName ===" -ForegroundColor Cyan
    Write-Host "  Script Type: $ScriptType" -ForegroundColor Gray
    Write-Host "  Command: $(if ($scriptContent.Length -gt 80) { $scriptContent.Substring(0,80) + '...' } else { $scriptContent })" -ForegroundColor Gray
    Write-Host ""

    # Execute via VMware Tools
    $result = Invoke-VMScript -VM $vm -ScriptText $scriptContent `
        -ScriptType $ScriptType -GuestCredential $GuestCredential `
        -ErrorAction Stop

    Write-Host "── Output ──" -ForegroundColor Yellow
    Write-Host $result.ScriptOutput

    if ($result.ExitCode -ne 0) {
        Write-Warning "Script exited with code: $($result.ExitCode)"
    } else {
        Write-Host "`n  Exit code: 0 (success)" -ForegroundColor Green
    }

    return $result
}
