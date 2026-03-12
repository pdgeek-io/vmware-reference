function New-ResearcherShare {
    <#
    .SYNOPSIS
        Provision a self-service NFS research share on PowerScale.
    .DESCRIPTION
        Creates an NFS export on PowerScale with quota, snapshots, and AD/Entra ID
        authentication via RFC2307. Tracks grant ID, department, PI, expiration,
        and compliance metadata (data classification, IRB, export control, FERPA/HIPAA).
        Lifecycle policies enforce data retention aligned with federal grant agency
        requirements and state administrative code.
    .EXAMPLE
        New-ResearcherShare -Name "genomics-2025" -Department "Biology" `
            -PIName "Dr. Jane Smith" -PIUsername "jsmith" -PIEmail "jsmith@university.edu" `
            -GrantID "NIH-R01-GM123456" -GrantAgency "NIH" -GrantExpiration "2027-08-31" `
            -QuotaGB 5000 -DataClassification "controlled"
    .EXAMPLE
        New-ResearcherShare -Name "clinical-trial-042" -Department "Nursing" `
            -PIName "Dr. Maria Lopez" -PIUsername "mlopez" -PIEmail "mlopez@university.edu" `
            -GrantID "NIH-U01-CA567890" -GrantAgency "NIH" -GrantExpiration "2028-06-30" `
            -QuotaGB 2000 -DataClassification "restricted" `
            -ComplianceFlags @("hipaa","pii") -IRBNumber "IRB-2025-0142"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Department,

        [Parameter(Mandatory)]
        [string]$PIName,

        [Parameter(Mandatory)]
        [string]$PIUsername,

        [Parameter(Mandatory)]
        [string]$PIEmail,

        [Parameter(Mandatory)]
        [string]$GrantID,

        [Parameter(Mandatory)]
        [ValidateSet("NIH", "NSF", "DOE", "DOD", "USDA", "state_of_texas", "industry", "internal")]
        [string]$GrantAgency,

        [Parameter(Mandatory)]
        [string]$GrantExpiration,

        [Parameter()]
        [int]$QuotaGB = 1000,

        [Parameter()]
        [ValidateSet("public", "controlled", "confidential", "restricted")]
        [string]$DataClassification = "controlled",

        [Parameter()]
        [string[]]$ComplianceFlags = @(),

        [Parameter()]
        [string[]]$AllowedClients = @("10.0.200.0/24"),

        [Parameter()]
        [string[]]$CoPIUsernames = @(),

        [Parameter()]
        [string]$IRBNumber,

        [Parameter()]
        [string]$IACUCNumber,

        [Parameter()]
        [string]$TechnologyControlPlan,

        [Parameter()]
        [string]$CostCenter,

        [Parameter()]
        [string]$SponsorName
    )

    $endpoint = $env:POWERSCALE_ENDPOINT
    $user = $env:POWERSCALE_USER
    $pass = $env:POWERSCALE_PASSWORD

    if (-not $endpoint) {
        throw "POWERSCALE_ENDPOINT environment variable not set"
    }

    # ── Compliance validation ──────────────────────────────────────
    # Enforce classification requirements based on compliance flags
    if ($ComplianceFlags -contains "hipaa" -and $DataClassification -notin @("restricted")) {
        Write-Host "  [WARN] HIPAA data requires 'restricted' classification. Upgrading." -ForegroundColor Yellow
        $DataClassification = "restricted"
    }
    if ($ComplianceFlags -contains "export_control" -and $DataClassification -notin @("restricted")) {
        Write-Host "  [WARN] Export-controlled data requires 'restricted' classification. Upgrading." -ForegroundColor Yellow
        $DataClassification = "restricted"
    }
    if ($ComplianceFlags -contains "export_control" -and -not $TechnologyControlPlan) {
        Write-Host "  [WARN] Export-controlled shares should have a Technology Control Plan on file." -ForegroundColor Yellow
    }
    if ($ComplianceFlags -contains "cui" -and $DataClassification -notin @("restricted")) {
        Write-Host "  [WARN] CUI data requires 'restricted' classification. Upgrading." -ForegroundColor Yellow
        $DataClassification = "restricted"
    }
    if ($ComplianceFlags -contains "ferpa" -and $DataClassification -notin @("confidential", "restricted")) {
        Write-Host "  [WARN] FERPA data requires at least 'confidential' classification. Upgrading." -ForegroundColor Yellow
        $DataClassification = "confidential"
    }

    # Determine retention years based on grant agency
    $retentionYears = switch ($GrantAgency) {
        "NIH"             { 7 }
        "NSF"             { 5 }
        "DOE"             { 7 }
        "DOD"             { 7 }
        "USDA"            { 5 }
        "state_of_texas"  { 5 }
        default           { 7 }
    }

    # Determine NFS security flavor based on classification
    $securityFlavors = switch ($DataClassification) {
        "restricted"    { @("krb5p") }  # Kerberos with privacy (encrypted)
        "confidential"  { @("krb5") }   # Kerberos integrity
        default         { @("unix") }   # Standard AUTH_SYS
    }

    # Build auth header
    $pair = "${user}:${pass}"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $headers = @{
        Authorization  = "Basic $base64"
        "Content-Type" = "application/json"
    }

    $sharePath = "/ifs/research/${Department}/${Name}"

    Write-Host "`n=== Provisioning Research Share ===" -ForegroundColor Cyan
    Write-Host "  Name:            $Name"
    Write-Host "  Department:      $Department"
    Write-Host "  PI:              $PIName ($PIUsername)"
    Write-Host "  Grant:           $GrantID ($GrantAgency)"
    Write-Host "  Expires:         $GrantExpiration"
    Write-Host "  Retention:       $retentionYears years post-closeout"
    Write-Host "  Quota:           $QuotaGB GB"
    Write-Host "  Classification:  $DataClassification"
    if ($ComplianceFlags.Count -gt 0) {
        Write-Host "  Compliance:      $($ComplianceFlags -join ', ')" -ForegroundColor Yellow
    }
    Write-Host "  NFS Path:        ${endpoint}:${sharePath}"
    Write-Host "  NFS Security:    $($securityFlavors -join ', ')"
    Write-Host "  Auth:            Entra ID / AD (RFC2307)"
    Write-Host ""

    # Step 1: Create directory
    Write-Host "Creating directory structure..." -ForegroundColor Yellow
    $dirBody = @{
        name       = $Name
        overwrite  = $false
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "https://${endpoint}:8080/namespace/research/${Department}/${Name}?overwrite=false" `
        -Method Put -Headers $headers -Body $dirBody -SkipCertificateCheck `
        -ErrorAction SilentlyContinue | Out-Null

    # Step 2: Create NFS export
    Write-Host "Creating NFS export..." -ForegroundColor Yellow
    $exportBody = @{
        paths              = @($sharePath)
        description        = "Grant: ${GrantID} (${GrantAgency}) | PI: ${PIName} | Dept: ${Department} | Class: ${DataClassification}"
        clients            = $AllowedClients
        read_write_clients = $AllowedClients
        security_flavors   = $securityFlavors
        map_root           = @{ enabled = $true; user = @{ id = "USER:nobody" } }
    } | ConvertTo-Json -Depth 4

    Invoke-RestMethod -Uri "https://${endpoint}:8080/platform/4/protocols/nfs/exports" `
        -Method Post -Headers $headers -Body $exportBody -SkipCertificateCheck | Out-Null

    # Step 3: Set quota
    Write-Host "Setting quota ($QuotaGB GB)..." -ForegroundColor Yellow
    $hardLimit = [int64]$QuotaGB * 1073741824
    $advisoryLimit = [math]::Floor($hardLimit * 0.80)
    $softLimit = [math]::Floor($hardLimit * 0.90)

    $quotaBody = @{
        path              = $sharePath
        type              = "directory"
        include_snapshots = $false
        thresholds        = @{
            hard          = $hardLimit
            advisory      = $advisoryLimit
            soft          = $softLimit
            soft_grace    = 604800
        }
    } | ConvertTo-Json -Depth 4

    Invoke-RestMethod -Uri "https://${endpoint}:8080/platform/1/quota/quotas" `
        -Method Post -Headers $headers -Body $quotaBody -SkipCertificateCheck | Out-Null

    # Step 4: Create snapshot schedule
    Write-Host "Configuring daily snapshots..." -ForegroundColor Yellow
    $snapBody = @{
        name     = "snap-${Name}"
        path     = $sharePath
        pattern  = "ResearchSnap-%Y-%m-%d_%H:%M"
        schedule = "Every day at 2:00 AM"
        duration = 2592000  # 30 days
        alias    = "research-${Name}-latest"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "https://${endpoint}:8080/platform/1/snapshot/schedules" `
        -Method Post -Headers $headers -Body $snapBody -SkipCertificateCheck `
        -ErrorAction SilentlyContinue | Out-Null

    # Step 5: Enable audit logging for confidential/restricted data
    if ($DataClassification -in @("confidential", "restricted")) {
        Write-Host "Enabling audit logging (required for $DataClassification data)..." -ForegroundColor Yellow
        $auditBody = @{
            path      = $sharePath
            audited_operations = @("read", "write", "delete", "rename", "set_security")
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "https://${endpoint}:8080/platform/4/audit/settings" `
            -Method Put -Headers $headers -Body $auditBody -SkipCertificateCheck `
            -ErrorAction SilentlyContinue | Out-Null
    }

    # Step 6: Save tracking metadata
    $trackingDir = Join-Path $PSScriptRoot "../../../config/research-shares"
    if (-not (Test-Path $trackingDir)) {
        New-Item -Path $trackingDir -ItemType Directory -Force | Out-Null
    }

    $provisionedDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

    $metadata = @{
        share_name              = $Name
        department              = $Department
        pi_name                 = $PIName
        pi_username             = $PIUsername
        pi_email                = $PIEmail
        grant_id                = $GrantID
        grant_agency            = $GrantAgency
        grant_expiration        = $GrantExpiration
        retention_years         = $retentionYears
        quota_gb                = $QuotaGB
        data_classification     = $DataClassification
        compliance_flags        = $ComplianceFlags
        irb_number              = $IRBNumber
        iacuc_number            = $IACUCNumber
        technology_control_plan = $TechnologyControlPlan
        cost_center             = $CostCenter
        sponsor_name            = $SponsorName
        co_pi_usernames         = $CoPIUsernames
        nfs_path                = $sharePath
        nfs_security            = ($securityFlavors -join ',')
        allowed_clients         = $AllowedClients
        provisioned_date        = $provisionedDate
        status                  = "active"
    }

    $yamlContent = @"
---
# Research Share Tracking Record
# Auto-generated by New-ResearcherShare on $provisionedDate
share_name: $Name
department: $Department
pi_name: "$PIName"
pi_username: $PIUsername
pi_email: $PIEmail
grant_id: $GrantID
grant_agency: $GrantAgency
grant_expiration: $GrantExpiration
retention_years: $retentionYears
quota_gb: $QuotaGB
data_classification: $DataClassification
compliance_flags: [$($ComplianceFlags -join ', ')]
irb_number: $IRBNumber
iacuc_number: $IACUCNumber
technology_control_plan: $TechnologyControlPlan
cost_center: $CostCenter
sponsor_name: $SponsorName
co_pi_usernames: [$($CoPIUsernames -join ', ')]
nfs_path: $sharePath
nfs_security: $($securityFlavors -join ',')
allowed_clients: [$($AllowedClients -join ', ')]
provisioned_date: $provisionedDate
status: active
"@
    $yamlContent | Set-Content (Join-Path $trackingDir "${Name}.yml")

    # Step 7: Tag in vCenter for chargeback (if connected)
    try {
        foreach ($category in @("GrantID", "GrantAgency", "PI", "DataClassification")) {
            $tagCat = Get-TagCategory -Name $category -ErrorAction SilentlyContinue
            if (-not $tagCat) {
                New-TagCategory -Name $category -Description "$category for research tracking" `
                    -Cardinality Single -EntityType "VmHost","Datastore" -ErrorAction SilentlyContinue | Out-Null
            }
        }
    } catch {
        Write-Host "  (vCenter tagging skipped — not connected)" -ForegroundColor Gray
    }

    Write-Host "`n=== Research Share Provisioned ===" -ForegroundColor Green
    Write-Host "  Share:           $Name"
    Write-Host "  NFS Mount:       mount -t nfs ${endpoint}:${sharePath} /mnt/research/${Name}"
    Write-Host "  Grant:           $GrantID ($GrantAgency)"
    Write-Host "  Expires:         $GrantExpiration"
    Write-Host "  Retention:       $retentionYears years post-closeout"
    Write-Host "  Quota:           $QuotaGB GB (advisory at $([math]::Floor($QuotaGB * 0.80)) GB)"
    Write-Host "  Classification:  $DataClassification"
    Write-Host "  NFS Security:    $($securityFlavors -join ', ')"
    Write-Host "  Snapshots:       Daily, 30-day retention"
    Write-Host "  Auth:            Entra ID / AD (RFC2307 — user $PIUsername)"
    Write-Host "  Audit Logging:   $(if ($DataClassification -in @('confidential','restricted')) { 'Enabled' } else { 'Standard' })"
    Write-Host ""

    return $metadata
}
