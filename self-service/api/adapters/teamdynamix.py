"""
pdgeek.io — TeamDynamix (TDX) ITSM Adapter
Integrates with TeamDynamix REST API — widely used in higher education
for ITSM, project management, and IT service catalogs.

Required environment variables:
  TDX_BASE_URL      — e.g., "https://university.teamdynamix.com"
  TDX_APP_ID        — TDX application ID for tickets
  TDX_BEID          — TDX BE ID (admin API auth)
  TDX_WEB_SERVICES_KEY — TDX Web Services Key (admin API auth)
"""

import os
import logging

import httpx

from .base import BaseAdapter
from models.requests import CMDBAsset, ServiceRequest, AssetType

logger = logging.getLogger(__name__)


class TeamDynamixAdapter(BaseAdapter):
    def __init__(self):
        self.base_url = os.getenv("TDX_BASE_URL", "").rstrip("/")
        self.app_id = os.getenv("TDX_APP_ID", "")
        self.beid = os.getenv("TDX_BEID", "")
        self.ws_key = os.getenv("TDX_WEB_SERVICES_KEY", "")
        self._token = None

    def _get_token(self) -> str:
        """Authenticate with TDX Admin API and get a bearer token."""
        if self._token:
            return self._token

        auth_url = f"{self.base_url}/TDWebApi/api/auth/loginadmin"
        payload = {"BEID": self.beid, "WebServicesKey": self.ws_key}

        resp = httpx.post(auth_url, json=payload, timeout=30.0)
        resp.raise_for_status()
        self._token = resp.text.strip('"')
        return self._token

    def _client(self) -> httpx.Client:
        token = self._get_token()
        return httpx.Client(
            base_url=f"{self.base_url}/TDWebApi/api",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            timeout=30.0,
        )

    def create_request(self, request: ServiceRequest) -> dict:
        """Create a ticket in TeamDynamix."""
        # TDX ticket type IDs vary by institution — these are common defaults
        type_id = int(os.getenv("TDX_TICKET_TYPE_SERVICE_REQUEST", "682"))
        source_id = int(os.getenv("TDX_TICKET_SOURCE_API", "8"))
        status_id = int(os.getenv("TDX_STATUS_NEW", "432"))
        priority_id = int(os.getenv("TDX_PRIORITY_MEDIUM", "31"))

        resource_name = request.payload.get("vm_name") or request.payload.get("share_name", "N/A")

        payload = {
            "TypeID": type_id,
            "Title": f"[pdgeek.io] {request.request_type.value}: {resource_name}",
            "Description": (
                f"<p><b>Request ID:</b> {request.id}</p>"
                f"<p><b>Type:</b> {request.request_type.value}</p>"
                f"<p><b>Requestor:</b> {request.requestor_name} ({request.requestor_email})</p>"
                f"<p><b>Department:</b> {request.department}</p>"
                f"<p><b>Details:</b></p><pre>{request.payload}</pre>"
            ),
            "AccountID": int(os.getenv("TDX_ACCOUNT_ID", "0")),
            "StatusID": status_id,
            "PriorityID": priority_id,
            "SourceID": source_id,
            "RequestorEmail": request.requestor_email,
        }

        # Add custom attributes for pdgeek tracking
        custom_attrs = []
        pdgeek_id_attr = os.getenv("TDX_ATTR_PDGEEK_ID")
        if pdgeek_id_attr:
            custom_attrs.append({"ID": pdgeek_id_attr, "Value": request.id})
        dept_attr = os.getenv("TDX_ATTR_DEPARTMENT")
        if dept_attr:
            custom_attrs.append({"ID": dept_attr, "Value": request.department})
        if custom_attrs:
            payload["Attributes"] = custom_attrs

        try:
            with self._client() as client:
                resp = client.post(f"/{self.app_id}/tickets", json=payload)
                resp.raise_for_status()
                data = resp.json()
                request.itsm_ticket_id = str(data.get("ID", ""))
                logger.info(f"TDX ticket created: {request.itsm_ticket_id}")
                return data
        except Exception as e:
            logger.error(f"TDX create_request failed: {e}")
            return {"error": str(e)}

    def update_request(self, request: ServiceRequest) -> dict:
        """Update a ticket in TeamDynamix via feed entry."""
        if not request.itsm_ticket_id:
            return {"skipped": "No TDX ticket ID"}

        # TDX uses feed entries for updates (not direct field patches for tickets)
        feed_payload = {
            "NewStatusID": int(os.getenv("TDX_STATUS_IN_PROCESS", "433")),
            "Comments": f"[pdgeek.io] Status: {request.status.value}",
            "IsPrivate": False,
        }

        if request.status.value == "completed":
            feed_payload["NewStatusID"] = int(os.getenv("TDX_STATUS_RESOLVED", "434"))
        elif request.status.value in ("failed", "cancelled"):
            feed_payload["NewStatusID"] = int(os.getenv("TDX_STATUS_CANCELLED", "435"))

        if request.cmdb_asset_id:
            feed_payload["Comments"] += f" | Asset ID: {request.cmdb_asset_id}"

        try:
            with self._client() as client:
                resp = client.post(
                    f"/{self.app_id}/tickets/{request.itsm_ticket_id}/feed",
                    json=feed_payload,
                )
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            logger.error(f"TDX update_request failed: {e}")
            return {"error": str(e)}

    def create_ci(self, asset: CMDBAsset) -> dict:
        """Create an asset/CI in TeamDynamix CMDB."""
        # TDX uses the Assets/CMDB module
        # Form IDs vary by institution; these map to typical CI types
        form_map = {
            AssetType.virtual_machine: int(os.getenv("TDX_FORM_VM", "0")),
            AssetType.research_share: int(os.getenv("TDX_FORM_STORAGE", "0")),
            AssetType.storage_volume: int(os.getenv("TDX_FORM_STORAGE", "0")),
        }
        form_id = form_map.get(asset.asset_type, 0)

        # TDX status IDs: Active=9, In Use=10, Disposed=14
        status_map = {
            "active": int(os.getenv("TDX_ASSET_STATUS_ACTIVE", "9")),
            "provisioning": int(os.getenv("TDX_ASSET_STATUS_ACTIVE", "9")),
            "decommissioned": int(os.getenv("TDX_ASSET_STATUS_DISPOSED", "14")),
        }

        payload = {
            "Name": asset.name,
            "StatusID": status_map.get(asset.status.value, 9),
            "FormID": form_id,
            "OwnerUID": asset.owner_email,  # TDX resolves by email
            "Description": (
                f"pdgeek.io {asset.asset_type.value} | "
                f"Dept: {asset.department} | "
                f"Request: {asset.request_id or 'manual'}"
            ),
        }

        # Custom attributes
        custom_attrs = []
        if asset.grant_id:
            grant_attr = os.getenv("TDX_ATTR_GRANT_ID")
            if grant_attr:
                custom_attrs.append({"ID": grant_attr, "Value": asset.grant_id})
        if asset.cost_center:
            cc_attr = os.getenv("TDX_ATTR_COST_CENTER")
            if cc_attr:
                custom_attrs.append({"ID": cc_attr, "Value": asset.cost_center})
        if custom_attrs:
            payload["Attributes"] = custom_attrs

        try:
            with self._client() as client:
                resp = client.post("/assets", json=payload)
                resp.raise_for_status()
                data = resp.json()
                asset.itsm_ci_id = str(data.get("ID", ""))
                logger.info(f"TDX asset created: {asset.itsm_ci_id}")
                return data
        except Exception as e:
            logger.error(f"TDX create_ci failed: {e}")
            return {"error": str(e)}

    def update_ci(self, asset: CMDBAsset) -> dict:
        """Update an asset in TeamDynamix CMDB."""
        if not asset.itsm_ci_id:
            return {"skipped": "No TDX asset ID"}

        try:
            with self._client() as client:
                # TDX requires a full asset object for updates
                resp = client.get(f"/assets/{asset.itsm_ci_id}")
                resp.raise_for_status()
                existing = resp.json()

                status_map = {
                    "active": int(os.getenv("TDX_ASSET_STATUS_ACTIVE", "9")),
                    "decommissioned": int(os.getenv("TDX_ASSET_STATUS_DISPOSED", "14")),
                }
                existing["StatusID"] = status_map.get(asset.status.value, existing.get("StatusID", 9))

                resp = client.post(f"/assets/{asset.itsm_ci_id}", json=existing)
                resp.raise_for_status()
                return resp.json()
        except Exception as e:
            logger.error(f"TDX update_ci failed: {e}")
            return {"error": str(e)}

    def close_request(self, request: ServiceRequest) -> dict:
        """Close a TDX ticket."""
        return self.update_request(request)
