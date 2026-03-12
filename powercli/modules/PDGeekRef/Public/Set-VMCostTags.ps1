function Set-VMCostTags {
    <#
    .SYNOPSIS
        Create and assign chargeback tags (Department, Project, Owner) to VMs.
    .DESCRIPTION
        Sets up the tag categories for cost tracking and assigns tags to VMs.
        These tags are used by Get-VMChargeback for showback reporting.
    .EXAMPLE
        Set-VMCostTags -VMName "web-01" -Department "Engineering" -Project "RefApp" -Owner "jsmith"
    .EXAMPLE
        Get-VM -Location "Reference-VMs" | Set-VMCostTags -Department "Platform" -Project "Lab"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "ByObject")]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$VM,

        [Parameter(Mandatory, ParameterSetName = "ByName")]
        [string]$VMName,

        [Parameter(Mandatory)]
        [string]$Department,

        [Parameter()]
        [string]$Project = "",

        [Parameter()]
        [string]$Owner = ""
    )

    begin {
        Connect-RefEnvironment

        # Ensure tag categories exist
        $categories = @("Department", "Project", "Owner")
        foreach ($cat in $categories) {
            $existing = Get-TagCategory -Name $cat -ErrorAction SilentlyContinue
            if (-not $existing) {
                Write-Host "  Creating tag category: $cat" -ForegroundColor Yellow
                New-TagCategory -Name $cat -Cardinality Single -EntityType VirtualMachine -Description "pdgeek.io chargeback - $cat" | Out-Null
            }
        }
    }

    process {
        if ($VMName) {
            $VM = Get-VM -Name $VMName -ErrorAction Stop
        }

        $tagAssignments = @{
            "Department" = $Department
            "Project"    = $Project
            "Owner"      = $Owner
        }

        foreach ($entry in $tagAssignments.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($entry.Value)) { continue }

            $category = Get-TagCategory -Name $entry.Key
            $tag = Get-Tag -Category $category -Name $entry.Value -ErrorAction SilentlyContinue
            if (-not $tag) {
                Write-Host "  Creating tag: $($entry.Key)/$($entry.Value)" -ForegroundColor Yellow
                $tag = New-Tag -Name $entry.Value -Category $category
            }

            # Remove existing tag in this category first
            $existing = $VM | Get-TagAssignment -Category $category -ErrorAction SilentlyContinue
            if ($existing) {
                $existing | Remove-TagAssignment -Confirm:$false
            }

            $VM | New-TagAssignment -Tag $tag | Out-Null
        }

        Write-Host "  [$($VM.Name)] Department=$Department, Project=$Project, Owner=$Owner" -ForegroundColor Green
    }
}
