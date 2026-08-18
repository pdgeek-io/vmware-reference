# Placeholder cleanup for security, EDR, monitoring, backup, and management
# agents in reusable Windows templates.
#
# Do not bake registered agent identity into a golden image. Add customer/vendor
# specific reset commands here when a tool is introduced. This script is safe to
# run before those tools exist; it records what it found and leaves placeholders
# for required vendor cleanup.
$ErrorActionPreference = "Stop"

Write-Host "==> Cleaning Windows security/management agent template state..."

$evidenceDir = "C:\ProgramData\PDGeek\TemplateHardening"
$evidenceFile = Join-Path $evidenceDir "windows-agent-cleanup.json"
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null

$agentPlaceholders = @(
    @{
        Name = "CrowdStrike Falcon"
        Services = @("CSFalconService")
        Paths = @("C:\ProgramData\CrowdStrike")
        Notes = "Add vendor-supported sensor grouping/CID reset or uninstall/reinstall workflow here."
    },
    @{
        Name = "Microsoft Defender for Endpoint"
        Services = @("Sense")
        Paths = @("C:\ProgramData\Microsoft\Windows Defender Advanced Threat Protection")
        Notes = "Add supported offboarding/onboarding cleanup for customer tenant images here."
    },
    @{
        Name = "SentinelOne"
        Services = @("SentinelAgent")
        Paths = @("C:\ProgramData\Sentinel")
        Notes = "Add vendor-supported agent identity reset or uninstall workflow here."
    },
    @{
        Name = "Tanium"
        Services = @("Tanium Client")
        Paths = @("C:\Program Files (x86)\Tanium\Tanium Client")
        Notes = "Clear registration/client identity only through approved Tanium procedure."
    },
    @{
        Name = "N-able/N-central"
        Services = @("Windows Agent Service", "NableAgent")
        Paths = @("C:\Program Files (x86)\N-able Technologies", "C:\ProgramData\N-able Technologies")
        Notes = "Add customer-approved agent GUID/cache cleanup here."
    },
    @{
        Name = "Datto RMM"
        Services = @("CagService")
        Paths = @("C:\Program Files (x86)\CentraStage", "C:\ProgramData\CentraStage")
        Notes = "Add customer-approved device ID/cache cleanup here."
    },
    @{
        Name = "Veeam"
        Services = @("VeeamEndpointBackupSvc")
        Paths = @("C:\ProgramData\Veeam")
        Notes = "Clear job/session/cache state if the agent is intentionally included."
    },
    @{
        Name = "Splunk Universal Forwarder"
        Services = @("SplunkForwarder")
        Paths = @("C:\Program Files\SplunkUniversalForwarder")
        Notes = "Clear deployment client identity and fishbucket only when required by design."
    }
)

$results = @()
foreach ($agent in $agentPlaceholders) {
    $foundServices = @()
    $foundPaths = @()

    foreach ($serviceName in $agent.Services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Host "  Found service for $($agent.Name): ${serviceName}"
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
            $foundServices += $serviceName
        }
    }

    foreach ($path in $agent.Paths) {
        if (Test-Path $path) {
            Write-Host "  Found agent path for $($agent.Name): ${path}"
            $foundPaths += $path
        }
    }

    $results += [ordered]@{
        name          = $agent.Name
        servicesFound = $foundServices
        pathsFound    = $foundPaths
        cleanupStatus = if ($foundServices.Count -gt 0 -or $foundPaths.Count -gt 0) { "placeholder-required" } else { "not-present" }
        notes         = $agent.Notes
    }
}

$results |
    ConvertTo-Json -Depth 5 |
    Set-Content -Path $evidenceFile -Encoding UTF8

Write-Host "==> Agent cleanup evidence written to ${evidenceFile}"
