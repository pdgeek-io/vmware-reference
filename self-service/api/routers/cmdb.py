"""
pdgeek.io — CMDB Router
Configuration Management Database for tracking assets (VMs, shares, volumes).
Supports sync to external ITSM CMDB (ServiceNow, TeamDynamix, etc.).
"""

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Query

from models.requests import (
    AssetStatus,
    AssetType,
    CMDBAsset,
    CMDBAssetUpdate,
)

router = APIRouter()

# Shared asset store (imported by requests router via module-level reference)
# In production, this would be a database
from routers.requests import _assets


@router.get("/cmdb/assets")
def list_assets(
    asset_type: Optional[AssetType] = None,
    status: Optional[AssetStatus] = None,
    department: Optional[str] = None,
    grant_id: Optional[str] = None,
    limit: int = Query(default=100, le=500),
):
    """
    List CMDB assets with optional filters.

    Supports filtering by type (virtual_machine, research_share, storage_volume),
    status, department, or grant ID. Returns assets sorted by creation date.
    """
    results = list(_assets.values())

    if asset_type:
        results = [a for a in results if a.asset_type == asset_type]
    if status:
        results = [a for a in results if a.status == status]
    if department:
        results = [a for a in results if a.department == department]
    if grant_id:
        results = [a for a in results if a.grant_id == grant_id]

    results.sort(key=lambda a: a.created_at, reverse=True)
    return {"assets": [a.model_dump() for a in results[:limit]], "total": len(results)}


@router.get("/cmdb/assets/{asset_id}")
def get_asset(asset_id: str):
    """Get a specific CMDB asset by ID."""
    if asset_id not in _assets:
        raise HTTPException(status_code=404, detail=f"Asset '{asset_id}' not found")
    return _assets[asset_id].model_dump()


@router.patch("/cmdb/assets/{asset_id}")
def update_asset(asset_id: str, update: CMDBAssetUpdate):
    """
    Update a CMDB asset.

    Used to update ITSM CI linkage, status changes, cost tracking, etc.
    Changes are synced to external ITSM if an adapter is configured.
    """
    if asset_id not in _assets:
        raise HTTPException(status_code=404, detail=f"Asset '{asset_id}' not found")

    asset = _assets[asset_id]

    if update.status is not None:
        asset.status = update.status
    if update.attributes is not None:
        asset.attributes.update(update.attributes)
    if update.itsm_ci_id is not None:
        asset.itsm_ci_id = update.itsm_ci_id
    if update.itsm_ci_sys_id is not None:
        asset.itsm_ci_sys_id = update.itsm_ci_sys_id
    if update.cost_center is not None:
        asset.cost_center = update.cost_center
    if update.monthly_cost is not None:
        asset.monthly_cost = update.monthly_cost
    if update.expiration_date is not None:
        asset.expiration_date = update.expiration_date

    asset.updated_at = datetime.utcnow()
    _assets[asset_id] = asset

    # Sync to ITSM
    from adapters import get_adapter
    adapter = get_adapter()
    if adapter:
        adapter.update_ci(asset)

    return asset.model_dump()


@router.post("/cmdb/assets")
def create_asset(asset: CMDBAsset):
    """
    Manually register a CMDB asset.

    Use this to import existing VMs or shares into the CMDB
    without going through the request workflow.
    """
    if not asset.id:
        asset.id = f"CI-{uuid.uuid4().hex[:8].upper()}"
    asset.created_at = datetime.utcnow()
    asset.updated_at = datetime.utcnow()
    _assets[asset.id] = asset

    from adapters import get_adapter
    adapter = get_adapter()
    if adapter:
        adapter.create_ci(asset)

    return asset.model_dump()


@router.post("/cmdb/sync")
def sync_cmdb():
    """
    Trigger a full CMDB sync to the configured ITSM platform.

    Pushes all local assets to the external CMDB. Useful for initial
    import or reconciliation after drift.
    """
    from adapters import get_adapter
    adapter = get_adapter()
    if not adapter:
        raise HTTPException(status_code=400, detail="No ITSM adapter configured. Set ITSM_PROVIDER env var.")

    synced = 0
    errors = []
    for asset in _assets.values():
        try:
            adapter.create_ci(asset)
            synced += 1
        except Exception as e:
            errors.append({"asset_id": asset.id, "error": str(e)})

    return {
        "synced": synced,
        "errors": len(errors),
        "details": errors if errors else "All assets synced successfully",
    }


@router.get("/cmdb/summary")
def cmdb_summary():
    """
    CMDB summary dashboard — asset counts by type, status, and department.
    """
    assets = list(_assets.values())

    by_type = {}
    by_status = {}
    by_department = {}

    for a in assets:
        by_type[a.asset_type.value] = by_type.get(a.asset_type.value, 0) + 1
        by_status[a.status.value] = by_status.get(a.status.value, 0) + 1
        by_department[a.department] = by_department.get(a.department, 0) + 1

    total_monthly_cost = sum(a.monthly_cost or 0 for a in assets)

    return {
        "total_assets": len(assets),
        "by_type": by_type,
        "by_status": by_status,
        "by_department": by_department,
        "total_monthly_cost": round(total_monthly_cost, 2),
    }
