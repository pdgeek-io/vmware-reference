# pdgeek.io — VMware Reference Architecture PowerCLI Module
# Self-service VM provisioning from catalog definitions

$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue

foreach ($function in @($PublicFunctions + $PrivateFunctions)) {
    try {
        . $function.FullName
    } catch {
        Write-Error "Failed to import function $($function.FullName): $_"
    }
}

Export-ModuleMember -Function $PublicFunctions.BaseName
