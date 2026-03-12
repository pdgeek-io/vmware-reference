"""
pdgeek.io — Chargeback Router
Exposes chargeback/showback data for ITSM billing integration.
Reports by department, grant, cost center — aligned with state fiscal year.
"""

from datetime import datetime
from pathlib import Path
from typing import Optional

import yaml
from fastapi import APIRouter, Query

router = APIRouter()

PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
RATES_FILE = PROJECT_ROOT / "chargeback" / "templates" / "rates.yml"
RESEARCH_SHARES_DIR = PROJECT_ROOT / "config" / "research-shares"

_DEFAULT_RATES = {
    "CpuPerVCpuMonth": 15.00,
    "MemoryPerGBMonth": 5.00,
    "StoragePerGBMonth": 0.10,
    "PowerStorePerGBMonth": 0.15,
    "PowerScalePerGBMonth": 0.05,
    "NetworkPerVNICMonth": 2.00,
}

_rates_cache: dict | None = None
_rates_mtime: float = 0.0


def _load_rates() -> dict:
    global _rates_cache, _rates_mtime
    if not RATES_FILE.exists():
        return _DEFAULT_RATES
    mtime = RATES_FILE.stat().st_mtime
    if _rates_cache is not None and mtime == _rates_mtime:
        return _rates_cache
    with open(RATES_FILE) as f:
        _rates_cache = yaml.safe_load(f) or _DEFAULT_RATES
    _rates_mtime = mtime
    return _rates_cache


_shares_cache: list | None = None
_shares_dir_mtime: float = 0.0


def _load_research_shares() -> list:
    """Load research share YAML files, cached until directory changes."""
    global _shares_cache, _shares_dir_mtime
    if not RESEARCH_SHARES_DIR.exists():
        return []
    mtime = RESEARCH_SHARES_DIR.stat().st_mtime
    if _shares_cache is not None and mtime == _shares_dir_mtime:
        return _shares_cache
    shares = []
    for f in sorted(RESEARCH_SHARES_DIR.glob("*.yml")):
        if f.name == ".gitkeep":
            continue
        with open(f) as fh:
            data = yaml.safe_load(fh)
            if data:
                shares.append(data)
    _shares_cache = shares
    _shares_dir_mtime = mtime
    return _shares_cache


def _get_fiscal_year() -> tuple[str, datetime]:
    """Return current Texas state fiscal year label and start date."""
    now = datetime.utcnow()
    if now.month >= 9:
        fy_start = datetime(now.year, 9, 1)
        fy_label = f"FY{str(now.year + 1)[2:]}"
    else:
        fy_start = datetime(now.year - 1, 9, 1)
        fy_label = f"FY{str(now.year)[2:]}"
    return fy_label, fy_start


@router.get("/chargeback/rates")
def get_rates():
    """Get current chargeback rate card."""
    rates = _load_rates()
    fy_label, _ = _get_fiscal_year()
    return {"fiscal_year": fy_label, "rates": rates}


@router.get("/chargeback/research-shares")
def get_research_share_chargeback(
    department: Optional[str] = None,
    grant_agency: Optional[str] = None,
    grant_id: Optional[str] = None,
):
    """
    Chargeback report for research shares on PowerScale.

    Returns per-share costs billable to grant IDs or cost centers.
    Filterable by department, agency, or specific grant.
    Designed for export to ITSM billing modules.
    """
    rates = _load_rates()
    rate_per_gb = rates.get("PowerScalePerGBMonth", 0.05)
    fy_label, _ = _get_fiscal_year()

    shares = list(_load_research_shares())

    if department:
        shares = [s for s in shares if s.get("department") == department]
    if grant_agency:
        shares = [s for s in shares if s.get("grant_agency") == grant_agency]
    if grant_id:
        shares = [s for s in shares if s.get("grant_id") == grant_id]

    report = []
    for share in shares:
        quota = share.get("quota_gb", 0)
        monthly = round(quota * rate_per_gb, 2)
        annual = round(monthly * 12, 2)

        report.append({
            "share_name": share.get("share_name"),
            "department": share.get("department"),
            "pi_name": share.get("pi_name"),
            "grant_id": share.get("grant_id"),
            "grant_agency": share.get("grant_agency"),
            "quota_gb": quota,
            "monthly_cost": monthly,
            "annual_cost": annual,
            "billable_to": share.get("grant_id"),
            "cost_center": share.get("cost_center"),
            "grant_expiration": share.get("grant_expiration"),
            "data_classification": share.get("data_classification"),
            "status": share.get("status", "active"),
        })

    total_monthly = sum(r["monthly_cost"] for r in report)
    total_annual = sum(r["annual_cost"] for r in report)

    # Group by department
    dept_summary = {}
    for r in report:
        dept = r["department"]
        if dept not in dept_summary:
            dept_summary[dept] = {"shares": 0, "quota_gb": 0, "monthly_cost": 0}
        dept_summary[dept]["shares"] += 1
        dept_summary[dept]["quota_gb"] += r["quota_gb"]
        dept_summary[dept]["monthly_cost"] += r["monthly_cost"]

    return {
        "fiscal_year": fy_label,
        "rate_per_gb_month": rate_per_gb,
        "total_shares": len(report),
        "total_monthly_cost": round(total_monthly, 2),
        "total_annual_cost": round(total_annual, 2),
        "by_department": dept_summary,
        "shares": report,
    }


@router.get("/chargeback/summary")
def chargeback_summary():
    """
    High-level chargeback summary for ITSM dashboards.

    Returns totals by category (compute, storage, research) for the current
    state fiscal year. Suitable for embedding in ServiceNow/TeamDynamix portals.
    """
    fy_label, _ = _get_fiscal_year()

    # Research share costs
    research_data = get_research_share_chargeback()

    # CMDB-based compute costs would come from vSphere in production
    # For now, return the research share data and placeholder for compute
    return {
        "fiscal_year": fy_label,
        "research_storage": {
            "total_shares": research_data["total_shares"],
            "monthly_cost": research_data["total_monthly_cost"],
            "annual_cost": research_data["total_annual_cost"],
        },
        "compute": {
            "note": "VM compute costs available via Get-VMChargeback PowerCLI cmdlet or ITSM adapter sync",
        },
    }
