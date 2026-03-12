function New-VMFromTemplate {
    <#
    .SYNOPSIS
        Quick VM clone from a Packer template with minimal parameters.
    .EXAMPLE
        New-VMFromTemplate -Name "test-vm-01" -Template "tpl-ubuntu-2404" -IPAddress "10.0.200.100"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Template,

        [Parameter(Mandatory)]
        [string]$IPAddress,

        [Parameter()]
        [int]$CPU = 2,

        [Parameter()]
        [int]$MemoryMB = 4096,

        [Parameter()]
        [string]$Datastore = "PowerStore-DS01",

        [Parameter()]
        [string]$ResourcePool = "Development"
    )

    Connect-RefEnvironment

    $tpl = Get-Template -Name $Template -ErrorAction Stop
    $rp = Get-ResourcePool -Name $ResourcePool -ErrorAction Stop
    $ds = Get-Datastore -Name $Datastore -ErrorAction Stop

    Write-Host "Cloning $Template -> $Name ($CPU vCPU, $MemoryMB MB)..." -ForegroundColor Cyan

    $vm = New-VM -Name $Name -Template $tpl -ResourcePool $rp -Datastore $ds -ErrorAction Stop
    Set-VM -VM $vm -NumCpu $CPU -MemoryMB $MemoryMB -Confirm:$false | Out-Null
    Start-VM -VM $vm -Confirm:$false | Out-Null

    Write-Host "VM $Name deployed and powered on." -ForegroundColor Green
    return $vm
}
