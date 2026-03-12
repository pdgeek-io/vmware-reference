function Get-ResearchShareReport {
    <#
    .SYNOPSIS
        Generate a report of all research shares with grant, compliance, and chargeback data.
    .DESCRIPTION
        Reads tracking metadata from config/research-shares/ and reports on grant status,
        compliance flags, data classification, quota usage, and costs. Flags shares
        approaching quota or grant expiration. Supports filtering by department, agency,
        or classification level. Designed for state institutional compliance reporting.
    .EXAMPLE
        Get-ResearchShareReport
    .EXAMPLE
        Get-ResearchShareReport -Department "Biology" -OutputFormat CSV
    .EXAMPLE
        Get-ResearchShareReport -GrantAgency "NIH"
    .EXAMPLE
        Get-ResearchShareReport -ComplianceFlag "hipaa"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Department,

        [Parameter()]
        [string]$GrantAgency,

        [Parameter()]
        [string]$ComplianceFlag,

        [Parameter()]
        [ValidateSet("Table", "CSV", "JSON")]
        [string]$OutputFormat = "Table",

        [Parameter()]
        [string]$TrackingPath = "$PSScriptRoot/../../../config/research-shares"
    )

    $ratePerGBMonth = 0.05  # Subsidized research rate

    if (-not (Test-Path $TrackingPath)) {
        Write-Host "  No research shares found." -ForegroundColor Yellow
        return
    }

    $shares = Get-ChildItem -Path $TrackingPath -Filter "*.yml" |
        Where-Object { $_.Name -ne ".gitkeep" } |
        ForEach-Object {
            $data = Get-Content $_.FullName -Raw | ConvertFrom-Yaml
            $data
        }

    # Apply filters
    if ($Department) {
        $shares = $shares | Where-Object { $_.department -eq $Department }
    }
    if ($GrantAgency) {
        $shares = $shares | Where-Object { $_.grant_agency -eq $GrantAgency }
    }
    if ($ComplianceFlag) {
        $shares = $shares | Where-Object { $_.compliance_flags -contains $ComplianceFlag }
    }

    $today = Get-Date
    # State fiscal year starts September 1
    $fyStart = if ($today.Month -ge 9) {
        Get-Date -Year $today.Year -Month 9 -Day 1
    } else {
        Get-Date -Year ($today.Year - 1) -Month 9 -Day 1
    }
    $fyLabel = "FY$(($fyStart.Year + 1).ToString().Substring(2))"

    $report = @()

    foreach ($share in $shares) {
        $expDate = [datetime]::Parse($share.grant_expiration)
        $daysToExpiry = ($expDate - $today).Days
        $monthlyCost = [math]::Round($share.quota_gb * $ratePerGBMonth, 2)
        $retentionYears = if ($share.retention_years) { $share.retention_years } else { 7 }
        $retentionEnd = $expDate.AddYears($retentionYears)

        # Determine status
        $status = "Active"
        if ($share.status -eq "read_only") { $status = "Read-Only" }
        elseif ($daysToExpiry -le 0) { $status = "EXPIRED" }
        elseif ($daysToExpiry -le 30) { $status = "Expiring Soon" }
        elseif ($daysToExpiry -le 90) { $status = "Exp ${daysToExpiry}d" }

        # Compliance summary
        $flags = if ($share.compliance_flags -is [array]) { $share.compliance_flags } else { @() }
        $complianceSummary = if ($flags.Count -gt 0) { ($flags | ForEach-Object { $_.ToUpper() }) -join ',' } else { "-" }

        $report += [PSCustomObject]@{
            ShareName       = $share.share_name
            Department      = $share.department
            PI              = $share.pi_name
            GrantID         = $share.grant_id
            Agency          = $share.grant_agency
            QuotaGB         = $share.quota_gb
            MonthlyCost     = "`$$monthlyCost"
            GrantExpires    = $share.grant_expiration
            DaysToExpiry    = $daysToExpiry
            RetentionUntil  = $retentionEnd.ToString("yyyy-MM-dd")
            Status          = $status
            Classification  = $share.data_classification
            Compliance      = $complianceSummary
            NFSPath         = $share.nfs_path
            IRB             = $share.irb_number
            CostCenter      = $share.cost_center
        }
    }

    # Sort by expiration
    $report = $report | Sort-Object DaysToExpiry

    switch ($OutputFormat) {
        "CSV" {
            $csvPath = "research-share-report-${fyLabel}-$(Get-Date -Format 'yyyyMMdd').csv"
            $report | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "`n  Report exported to $csvPath" -ForegroundColor Green
        }
        "JSON" {
            $report | ConvertTo-Json -Depth 5
        }
        default {
            Write-Host "`n  ╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "  ║           Research Storage Report — PowerScale ($fyLabel)                  ║" -ForegroundColor Cyan
            Write-Host "  ╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""

            $report | Format-Table -AutoSize ShareName, Department, PI, Agency, GrantID, QuotaGB, MonthlyCost, Status, Classification, Compliance

            # Summary
            $totalShares = $report.Count
            $totalQuota = ($report | Measure-Object -Property QuotaGB -Sum).Sum
            $totalMonthlyCost = ($report | ForEach-Object { $_.QuotaGB * $ratePerGBMonth } | Measure-Object -Sum).Sum
            $annualCost = $totalMonthlyCost * 12
            $expiringSoon = ($report | Where-Object { $_.DaysToExpiry -le 90 -and $_.DaysToExpiry -gt 0 }).Count
            $expired = ($report | Where-Object { $_.DaysToExpiry -le 0 }).Count

            # Classification breakdown
            $classBreakdown = $report | Group-Object Classification | Sort-Object Name

            # Agency breakdown
            $agencyBreakdown = $report | Group-Object Agency | Sort-Object Count -Descending

            Write-Host "  ── Summary ──" -ForegroundColor Yellow
            Write-Host "  Total Shares:      $totalShares"
            Write-Host "  Total Quota:       $totalQuota GB"
            Write-Host "  Monthly Cost:      `$$([math]::Round($totalMonthlyCost, 2))"
            Write-Host "  Annual Cost ($fyLabel): `$$([math]::Round($annualCost, 2))"
            Write-Host "  Expiring (<90d):   $expiringSoon" -ForegroundColor $(if ($expiringSoon -gt 0) { "Yellow" } else { "White" })
            Write-Host "  Expired:           $expired" -ForegroundColor $(if ($expired -gt 0) { "Red" } else { "White" })

            Write-Host "`n  ── By Classification ──" -ForegroundColor Yellow
            foreach ($group in $classBreakdown) {
                $color = switch ($group.Name) {
                    "restricted"   { "Red" }
                    "confidential" { "Yellow" }
                    "controlled"   { "White" }
                    default        { "Green" }
                }
                Write-Host "  $($group.Name.PadRight(16)) $($group.Count) shares" -ForegroundColor $color
            }

            Write-Host "`n  ── By Agency ──" -ForegroundColor Yellow
            foreach ($group in $agencyBreakdown) {
                Write-Host "  $($group.Name.PadRight(16)) $($group.Count) shares"
            }

            # Compliance flags summary
            $allFlags = $report | Where-Object { $_.Compliance -ne "-" } | ForEach-Object { $_.Compliance -split ',' }
            if ($allFlags.Count -gt 0) {
                $flagSummary = $allFlags | Group-Object | Sort-Object Count -Descending
                Write-Host "`n  ── Compliance Flags ──" -ForegroundColor Yellow
                foreach ($flag in $flagSummary) {
                    Write-Host "  $($flag.Name.PadRight(16)) $($flag.Count) shares" -ForegroundColor $(
                        if ($flag.Name -in @("HIPAA","CUI","EXPORT_CONTROL")) { "Red" } else { "Yellow" }
                    )
                }
            }

            Write-Host ""
        }
    }

    return $report
}
