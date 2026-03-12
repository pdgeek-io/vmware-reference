"""
pdgeek.io — ITSM Webhook Router
Receives inbound webhooks from ServiceNow, TeamDynamix, and other ITSM platforms.
Translates ITSM events (approval, cancellation, update) into request lifecycle actions.
"""

import hmac
import hashlib
import os
from typing import Optional

from fastapi import APIRouter, HTTPException, Header, Request

from models.requests import RequestStatus, RequestUpdate

router = APIRouter()


@router.post("/webhooks/servicenow")
async def servicenow_webhook(
    request: Request,
    x_sn_webhook_token: Optional[str] = Header(default=None),
):
    """
    Receive webhooks from ServiceNow.

    ServiceNow can send webhooks on:
    - Request Item (RITM) approval/rejection
    - Change Request (CHG) state changes
    - Incident assignment

    Configure in ServiceNow: Business Rules or Flow Designer → REST Message
    pointing to this endpoint.
    """
    # Validate webhook token
    expected_token = os.getenv("SERVICENOW_WEBHOOK_TOKEN")
    if expected_token and x_sn_webhook_token != expected_token:
        raise HTTPException(status_code=401, detail="Invalid webhook token")

    body = await request.json()

    # ServiceNow typically sends:
    # { "sys_id": "...", "number": "RITM0012345", "state": "approved", ... }
    sn_number = body.get("number", "")
    sn_state = body.get("state", "").lower()
    sn_sys_id = body.get("sys_id", "")
    approver = body.get("approved_by", {}).get("email", "")

    # Map ServiceNow states to our request states
    state_map = {
        "approved": RequestStatus.approved,
        "rejected": RequestStatus.cancelled,
        "closed_complete": RequestStatus.completed,
        "closed_incomplete": RequestStatus.failed,
        "cancelled": RequestStatus.cancelled,
    }

    new_status = state_map.get(sn_state)
    if not new_status:
        return {"received": True, "action": "ignored", "reason": f"Unhandled state: {sn_state}"}

    # Find matching request by ITSM ticket ID
    from routers.requests import _requests
    matched = None
    for req in _requests.values():
        if req.itsm_ticket_id == sn_number:
            matched = req
            break

    if not matched:
        return {"received": True, "action": "ignored", "reason": f"No matching request for {sn_number}"}

    # Apply the update
    from routers.requests import update_request
    update = RequestUpdate(
        status=new_status,
        approver_email=approver,
        itsm_ticket_id=sn_number,
    )
    result = update_request(matched.id, update)

    return {
        "received": True,
        "action": "processed",
        "request_id": matched.id,
        "new_status": new_status.value,
        "servicenow_number": sn_number,
    }


@router.post("/webhooks/teamdynamix")
async def teamdynamix_webhook(
    request: Request,
    x_tdx_hmac: Optional[str] = Header(default=None),
):
    """
    Receive webhooks from TeamDynamix (TDX).

    TeamDynamix is widely used in higher education for ITSM/project management.
    Configure in TDX: Admin → Automation → Webhooks pointing to this endpoint.

    TDX webhook events:
    - Ticket status change (e.g., Approved, Resolved, Closed)
    - Ticket assignment change
    - Custom workflow step completion
    """
    body_bytes = await request.body()

    # Validate HMAC signature if configured
    hmac_secret = os.getenv("TDX_WEBHOOK_SECRET")
    if hmac_secret and x_tdx_hmac:
        expected = hmac.new(
            hmac_secret.encode(), body_bytes, hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(expected, x_tdx_hmac):
            raise HTTPException(status_code=401, detail="Invalid HMAC signature")

    import json
    body = json.loads(body_bytes)

    # TeamDynamix sends:
    # { "TicketID": 12345, "StatusName": "Approved", "RequestorEmail": "...", ... }
    tdx_ticket_id = str(body.get("TicketID", ""))
    tdx_status = body.get("StatusName", "").lower()
    tdx_requestor = body.get("RequestorEmail", "")
    tdx_approver = body.get("ResponsibleEmail", "")

    # Map TDX statuses
    state_map = {
        "approved": RequestStatus.approved,
        "resolved": RequestStatus.completed,
        "closed": RequestStatus.completed,
        "cancelled": RequestStatus.cancelled,
        "declined": RequestStatus.cancelled,
        "in process": RequestStatus.provisioning,
    }

    new_status = state_map.get(tdx_status)
    if not new_status:
        return {"received": True, "action": "ignored", "reason": f"Unhandled status: {tdx_status}"}

    from routers.requests import _requests
    matched = None
    for req in _requests.values():
        if req.itsm_ticket_id == tdx_ticket_id:
            matched = req
            break

    if not matched:
        return {"received": True, "action": "ignored", "reason": f"No matching request for TDX #{tdx_ticket_id}"}

    from routers.requests import update_request
    update = RequestUpdate(
        status=new_status,
        approver_email=tdx_approver,
        itsm_ticket_id=tdx_ticket_id,
    )
    result = update_request(matched.id, update)

    return {
        "received": True,
        "action": "processed",
        "request_id": matched.id,
        "new_status": new_status.value,
        "tdx_ticket_id": tdx_ticket_id,
    }


@router.post("/webhooks/generic")
async def generic_webhook(
    request: Request,
    x_webhook_token: Optional[str] = Header(default=None),
):
    """
    Generic webhook receiver for any ITSM platform.

    Accepts a standardized payload format that any ITSM can produce
    via REST integrations or middleware (e.g., Freshservice, Jira SM, Cherwell).

    Expected payload:
    {
        "ticket_id": "INC0012345",
        "action": "approve" | "cancel" | "complete" | "fail",
        "request_id": "REQ-XXXXXXXX",  (our internal ID)
        "approver_email": "admin@university.edu",
        "notes": "Optional notes"
    }
    """
    expected_token = os.getenv("WEBHOOK_TOKEN")
    if expected_token and x_webhook_token != expected_token:
        raise HTTPException(status_code=401, detail="Invalid webhook token")

    body = await request.json()

    action_map = {
        "approve": RequestStatus.approved,
        "cancel": RequestStatus.cancelled,
        "complete": RequestStatus.completed,
        "fail": RequestStatus.failed,
    }

    action = body.get("action", "").lower()
    new_status = action_map.get(action)
    if not new_status:
        raise HTTPException(status_code=400, detail=f"Unknown action: {action}. Use: approve, cancel, complete, fail")

    request_id = body.get("request_id")
    if not request_id:
        raise HTTPException(status_code=400, detail="request_id is required")

    from routers.requests import _requests, update_request
    if request_id not in _requests:
        raise HTTPException(status_code=404, detail=f"Request '{request_id}' not found")

    update = RequestUpdate(
        status=new_status,
        approver_email=body.get("approver_email"),
        itsm_ticket_id=body.get("ticket_id"),
    )
    result = update_request(request_id, update)

    return {
        "received": True,
        "action": "processed",
        "request_id": request_id,
        "new_status": new_status.value,
    }
