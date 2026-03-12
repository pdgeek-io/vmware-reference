function Remove-RefVM {
    <#
    .SYNOPSIS
        Remove a reference VM and reclaim its storage.
    .EXAMPLE
        Remove-RefVM -Name "dev-web-01"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    Connect-RefEnvironment

    $vm = Get-VM -Name $Name -ErrorAction Stop

    if ($PSCmdlet.ShouldProcess($Name, "Remove VM and reclaim storage")) {
        # Power off if running
        if ($vm.PowerState -eq "PoweredOn") {
            Write-Host "Powering off $Name..." -ForegroundColor Yellow
            Stop-VM -VM $vm -Confirm:$false | Out-Null
        }

        # Remove PowerStore volume if exists
        try {
            $volumeName = "${Name}-data"
            $uri = "https://$($script:PowerStoreEndpoint)/api/version/volume?name=eq.$volumeName"
            $volume = Invoke-RestMethod -Uri $uri -Method Get -Headers $script:PowerStoreHeaders -SkipCertificateCheck
            if ($volume) {
                Write-Host "Removing PowerStore volume: $volumeName" -ForegroundColor Yellow
                Invoke-RestMethod -Uri "https://$($script:PowerStoreEndpoint)/api/version/volume/$($volume.id)" `
                    -Method Delete -Headers $script:PowerStoreHeaders -SkipCertificateCheck | Out-Null
            }
        } catch {
            Write-Verbose "No PowerStore volume found for $Name"
        }

        # Remove VM
        Write-Host "Removing VM: $Name" -ForegroundColor Yellow
        Remove-VM -VM $vm -DeletePermanently -Confirm:$false

        Write-Host "VM $Name removed successfully." -ForegroundColor Green
    }
}
