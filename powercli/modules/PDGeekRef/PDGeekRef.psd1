@{
    RootModule        = 'PDGeekRef.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'pdgeek.io'
    Description       = 'pdgeek.io — VMware Reference Architecture — Self-Service VM Provisioning'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        'VMware.PowerCLI'
    )

    FunctionsToExport = @(
        'New-RefVM',
        'New-VMFromTemplate',
        'Set-PowerStoreDatastore',
        'Get-RefLabStatus',
        'Remove-RefVM'
    )
}
