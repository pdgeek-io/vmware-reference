"""
pdgeek.io — Request Workflow Router
ITSM-compatible request lifecycle: submit → approve → provision → complete.
Integrates with ServiceNow, TeamDynamix, or any ITSM via adapters.
"""

import json
import os
import subprocess
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

import yaml
from fastapi import APIRouter, HTTPException, Query

from models.requests import (
    CMDBAsset,
    AssetType,
    AssetStatus,
    RequestStatus,
    RequestType,
    RequestUpdate,
    ServiceRequest,
    VMProvisionRequest,
    ResearchShareRequest,
)

router = APIRouter()

# In-memory store for demo; production would use a database
_requests: dict[str, ServiceRequest] = {}
_assets: dict[str, CMDBAsset] = {}

CATALOG_DIR = Path(__file__).parent.parent.parent / "catalog"
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent


def _get_itsm_adapter():
    """Load the configured ITSM adapter."""
    from adapters import get_adapter
    return get_adapter()


def _get_powerscale_rate() -> float:
    """Get the PowerScale per-GB/month rate from the chargeback rate card."""
    from routers.chargeback import _load_rates
    return _load_rates().get("PowerScalePerGBMonth", 0.05)


# --- Request Lifecycle ---

@router.post("/requests/vm", status_code=202)
def submit_vm_request(request: VMProvisionRequest):
    """
    Submit a VM provisioning request.

    This creates a service request that follows the ITSM workflow:
    submitted → pending_approval → approved → provisioning → completed

    If auto_approve is enabled (demo mode), skips approval and provisions immediately.
    If an ITSM adapter is configured, the request is synced to the external system.
    """
    # Validate catalog item
    catalog_path = CATALOG_DIR / f"{request.catalog_item}.yml"
    if not catalog_path.exists():
        raise HTTPException(status_code=404, detail=f"Catalog item '{request.catalog_item}' not found")

    with open(catalog_path) as f:
        catalog = yaml.safe_load(f)

    req_id = f"REQ-{uuid.uuid4().hex[:8].upper()}"

    svc_request = ServiceRequest(
        id=req_id,
        request_type=RequestType.vm,
        requestor_name=request.requestor_name,
        requestor_email=request.requestor_email,
        department=request.department,
        itsm_ticket_id=request.itsm_ticket_id,
        change_request_id=request.change_request_id,
        payload={
            "catalog_item": request.catalog_item,
            "catalog_name": catalog.get("name", request.catalog_item),
            "vm_name": request.vm_name,
            "ip_address": request.ip_address,
            "gateway": request.gateway,
            "dns_servers": request.dns_servers,
            "department": request.department,
            "cost_center": request.cost_center,
            "justification": request.justification,
        },
    )

    # Auto-approve in demo mode
    if os.getenv("AUTO_APPROVE", "true").lower() == "true":
        svc_request.status = RequestStatus.approved
        svc_request.approver_email = "auto-approved@pdgeek.io"
        svc_request.approved_at = datetime.utcnow()
        _requests[req_id] = svc_request
        return _fulfill_vm_request(svc_request)

    svc_request.status = RequestStatus.pending_approval
    _requests[req_id] = svc_request

    # Sync to ITSM if configured
    adapter = _get_itsm_adapter()
    if adapter:
        adapter.create_request(svc_request)

    return {
        "request_id": req_id,
        "status": svc_request.status.value,
        "message": "Request submitted — pending approval",
        "itsm_ticket_id": svc_request.itsm_ticket_id,
    }


@router.post("/requests/research-share", status_code=202)
def submit_research_share_request(request: ResearchShareRequest):
    """
    Submit a research NFS share provisioning request.
    Follows the same ITSM workflow as VM requests.
    """
    req_id = f"REQ-{uuid.uuid4().hex[:8].upper()}"

    svc_request = ServiceRequest(
        id=req_id,
        request_type=RequestType.research_share,
        requestor_name=request.requestor_name,
        requestor_email=request.requestor_email,
        department=request.department,
        itsm_ticket_id=request.itsm_ticket_id,
        change_request_id=request.change_request_id,
        payload={
            "share_name": request.share_name,
            "department": request.department,
            "pi_name": request.pi_name,
            "pi_username": request.pi_username,
            "pi_email": request.pi_email,
            "grant_id": request.grant_id,
            "grant_agency": request.grant_agency,
            "grant_expiration": request.grant_expiration,
            "quota_gb": request.quota_gb,
            "data_classification": request.data_classification,
            "compliance_flags": request.compliance_flags,
            "irb_number": request.irb_number,
            "iacuc_number": request.iacuc_number,
            "cost_center": request.cost_center,
            "justification": request.justification,
        },
    )

    if os.getenv("AUTO_APPROVE", "true").lower() == "true":
        svc_request.status = RequestStatus.approved
        svc_request.approver_email = "auto-approved@pdgeek.io"
        svc_request.approved_at = datetime.utcnow()
        _requests[req_id] = svc_request
        return _fulfill_share_request(svc_request)

    svc_request.status = RequestStatus.pending_approval
    _requests[req_id] = svc_request

    adapter = _get_itsm_adapter()
    if adapter:
        adapter.create_request(svc_request)

    return {
        "request_id": req_id,
        "status": svc_request.status.value,
        "message": "Research share request submitted — pending approval",
        "itsm_ticket_id": svc_request.itsm_ticket_id,
    }


@router.get("/requests")
def list_requests(
    status: Optional[RequestStatus] = None,
    request_type: Optional[RequestType] = None,
    department: Optional[str] = None,
    limit: int = Query(default=50, le=200),
):
    """List service requests with optional filters."""
    results = list(_requests.values())

    if status:
        results = [r for r in results if r.status == status]
    if request_type:
        results = [r for r in results if r.request_type == request_type]
    if department:
        results = [r for r in results if r.department == department]

    results.sort(key=lambda r: r.created_at, reverse=True)
    return {"requests": [r.model_dump() for r in results[:limit]], "total": len(results)}


@router.get("/requests/{request_id}")
def get_request(request_id: str):
    """Get a specific service request by ID."""
    if request_id not in _requests:
        raise HTTPException(status_code=404, detail=f"Request '{request_id}' not found")
    return _requests[request_id].model_dump()


@router.patch("/requests/{request_id}")
def update_request(request_id: str, update: RequestUpdate):
    """
    Update a service request (approve, cancel, update ITSM linkage).
    Used by ITSM webhooks or manual approval workflows.
    """
    if request_id not in _requests:
        raise HTTPException(status_code=404, detail=f"Request '{request_id}' not found")

    req = _requests[request_id]

    if update.status:
        req.status = update.status
        req.updated_at = datetime.utcnow()

        if update.status == RequestStatus.approved:
            req.approver_email = update.approver_email
            req.approved_at = datetime.utcnow()
            # Auto-fulfill on approval
            if req.request_type == RequestType.vm:
                return _fulfill_vm_request(req)
            elif req.request_type == RequestType.research_share:
                return _fulfill_share_request(req)

        if update.status == RequestStatus.cancelled:
            adapter = _get_itsm_adapter()
            if adapter:
                adapter.update_request(req)

    if update.itsm_ticket_id:
        req.itsm_ticket_id = update.itsm_ticket_id
    if update.change_request_id:
        req.change_request_id = update.change_request_id
    if update.error_message:
        req.error_message = update.error_message

    _requests[request_id] = req

    return req.model_dump()


# --- Fulfillment ---

def _fulfill_vm_request(req: ServiceRequest) -> dict:
    """Trigger VM provisioning and create CMDB asset."""
    req.status = RequestStatus.provisioning
    req.updated_at = datetime.utcnow()
    _requests[req.id] = req

    payload = req.payload

    # Trigger PowerCLI — pass params via stdin JSON to avoid shell injection
    powercli_script = (
        f"Import-Module '{PROJECT_ROOT}/powercli/modules/PDGeekRef'; "
        "$p = $input | ConvertFrom-Json; "
        "New-RefVM -Name $p.vm_name -CatalogItem $p.catalog_item -IPAddress $p.ip_address"
    )
    proc = subprocess.Popen(
        ["pwsh", "-Command", powercli_script],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    proc.stdin.write(json.dumps({
        "vm_name": payload["vm_name"],
        "catalog_item": payload["catalog_item"],
        "ip_address": payload["ip_address"],
    }).encode())
    proc.stdin.close()

    # Create CMDB asset
    asset_id = f"CI-{uuid.uuid4().hex[:8].upper()}"
    asset = CMDBAsset(
        id=asset_id,
        asset_type=AssetType.virtual_machine,
        name=payload["vm_name"],
        status=AssetStatus.provisioning,
        department=payload["department"],
        owner_name=req.requestor_name,
        owner_email=req.requestor_email,
        request_id=req.id,
        cost_center=payload.get("cost_center"),
        attributes={
            "catalog_item": payload["catalog_item"],
            "catalog_name": payload.get("catalog_name", ""),
            "ip_address": payload["ip_address"],
            "gateway": payload.get("gateway", "10.0.200.1"),
        },
    )
    _assets[asset_id] = asset
    req.cmdb_asset_id = asset_id
    _requests[req.id] = req

    # Sync asset to ITSM CMDB
    adapter = _get_itsm_adapter()
    if adapter:
        adapter.create_ci(asset)
        adapter.update_request(req)

    return {
        "request_id": req.id,
        "status": "provisioning",
        "cmdb_asset_id": asset_id,
        "vm_name": payload["vm_name"],
        "ip_address": payload["ip_address"],
        "message": f"VM '{payload['vm_name']}' is being provisioned",
    }


def _fulfill_share_request(req: ServiceRequest) -> dict:
    """Trigger research share provisioning and create CMDB asset."""
    req.status = RequestStatus.provisioning
    req.updated_at = datetime.utcnow()
    _requests[req.id] = req

    payload = req.payload

    # Trigger PowerCLI — pass params via stdin JSON to avoid shell injection
    flags_expr = ""
    if payload.get("compliance_flags"):
        flags_expr = " -ComplianceFlags $p.compliance_flags"

    powercli_script = (
        f"Import-Module '{PROJECT_ROOT}/powercli/modules/PDGeekRef'; "
        "$p = $input | ConvertFrom-Json; "
        "New-ResearcherShare -Name $p.share_name -Department $p.department "
        "-PIName $p.pi_name -PIUsername $p.pi_username -PIEmail $p.pi_email "
        "-GrantID $p.grant_id -GrantAgency $p.grant_agency "
        "-GrantExpiration $p.grant_expiration -QuotaGB $p.quota_gb "
        f"-DataClassification $p.data_classification{flags_expr}"
    )
    proc = subprocess.Popen(
        ["pwsh", "-Command", powercli_script],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    proc.stdin.write(json.dumps({
        "share_name": payload["share_name"],
        "department": payload["department"],
        "pi_name": payload["pi_name"],
        "pi_username": payload["pi_username"],
        "pi_email": payload["pi_email"],
        "grant_id": payload["grant_id"],
        "grant_agency": payload["grant_agency"],
        "grant_expiration": payload["grant_expiration"],
        "quota_gb": payload["quota_gb"],
        "data_classification": payload["data_classification"],
        "compliance_flags": payload.get("compliance_flags", []),
    }).encode())
    proc.stdin.close()

    # Create CMDB asset
    asset_id = f"CI-{uuid.uuid4().hex[:8].upper()}"
    asset = CMDBAsset(
        id=asset_id,
        asset_type=AssetType.research_share,
        name=payload["share_name"],
        status=AssetStatus.provisioning,
        department=payload["department"],
        owner_name=payload["pi_name"],
        owner_email=payload["pi_email"],
        request_id=req.id,
        grant_id=payload["grant_id"],
        cost_center=payload.get("cost_center"),
        expiration_date=payload["grant_expiration"],
        monthly_cost=round(payload["quota_gb"] * _get_powerscale_rate(), 2),
        attributes={
            "pi_username": payload["pi_username"],
            "grant_agency": payload["grant_agency"],
            "quota_gb": payload["quota_gb"],
            "data_classification": payload["data_classification"],
            "compliance_flags": payload.get("compliance_flags", []),
            "irb_number": payload.get("irb_number"),
            "iacuc_number": payload.get("iacuc_number"),
            "nfs_path": f"/ifs/research/{payload['department']}/{payload['share_name']}",
        },
    )
    _assets[asset_id] = asset
    req.cmdb_asset_id = asset_id
    _requests[req.id] = req

    adapter = _get_itsm_adapter()
    if adapter:
        adapter.create_ci(asset)
        adapter.update_request(req)

    return {
        "request_id": req.id,
        "status": "provisioning",
        "cmdb_asset_id": asset_id,
        "share_name": payload["share_name"],
        "grant_id": payload["grant_id"],
        "message": f"Research share '{payload['share_name']}' is being provisioned",
    }
