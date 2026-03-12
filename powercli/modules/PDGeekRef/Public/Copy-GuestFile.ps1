function Copy-GuestFile {
    <#
    .SYNOPSIS
        Copy files to/from guest VMs via VMware Tools — no SSH/SCP needed.
    .DESCRIPTION
        Uses VMware Tools guest file operations to transfer files between
        the automation host and the guest OS. Useful for deploying configs,
        scripts, and retrieving logs without network connectivity to the guest.
    .EXAMPLE
        Copy-GuestFile -VMName "web-01" -Source "./configs/nginx.conf" -Destination "/etc/nginx/nginx.conf"
    .EXAMPLE
        Copy-GuestFile -VMName "db-01" -Source "/var/log/postgresql/postgresql.log" -Destination "./logs/" -FromGuest
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VMName,

        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter()]
        [switch]$FromGuest,

        [Parameter()]
        [PSCredential]$GuestCredential
    )

    Connect-RefEnvironment

    $vm = Get-VM -Name $VMName -ErrorAction Stop

    if (-not $GuestCredential) {
        $GuestCredential = Get-Credential -Message "Enter guest OS credentials for $VMName"
    }

    if ($FromGuest) {
        Write-Host "  Copying FROM guest: $VMName:$Source -> $Destination" -ForegroundColor Cyan
        Copy-VMGuestFile -Source $Source -Destination $Destination `
            -VM $vm -GuestToLocal -GuestCredential $GuestCredential `
            -ErrorAction Stop
    } else {
        Write-Host "  Copying TO guest: $Source -> $VMName:$Destination" -ForegroundColor Cyan
        Copy-VMGuestFile -Source $Source -Destination $Destination `
            -VM $vm -LocalToGuest -GuestCredential $GuestCredential `
            -ErrorAction Stop
    }

    Write-Host "  Transfer complete." -ForegroundColor Green
}
