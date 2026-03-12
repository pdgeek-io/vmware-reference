@{
    RootModule        = 'PDGeekRef.psm1'
    ModuleVersion     = '1.2.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'pdgeek.io'
    Description       = 'pdgeek.io — Day 2 operations: self-service VMs, research storage, guest automation, chargeback/showback'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        'VMware.PowerCLI'
    )

    FunctionsToExport = @(
        # Self-Service VM Provisioning
        'New-RefVM',
        'New-VMFromTemplate',
        'Remove-RefVM',

        # Infrastructure
        'Set-PowerStoreDatastore',
        'Get-RefLabStatus',

        # Chargeback / Showback
        'Get-VMChargeback',
        'Set-VMCostTags',
        'Get-VMLifecycle',

        # Research Storage (PowerScale)
        'New-ResearcherShare',
        'Get-ResearchShareReport',

        # Guest Automation (via VMware Tools)
        'Invoke-GuestAutomation',
        'Copy-GuestFile'
    )
}
