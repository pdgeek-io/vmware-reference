"""
pdgeek.io — ServiceNow ITSM Adapter
Integrates with ServiceNow REST API for request management and CMDB sync.

Required environment variables:
  SERVICENOW_INSTANCE   — e.g., "university.service-now.com"
  SERVICENOW_USER       — API user
  SERVICENOW_PASSWORD   — API password
"""

import os
import logging

import httpx

from .base import BaseAdapter
from models.requests import CMDBAsset, ServiceRequest, AssetType

logger = logging.getLogger(__name__)


class ServiceNowAdapter(BaseAdapter):

    CI_CLASS_MAP = {
        AssetType.virtual_machine: "cmdb_ci_vm_instance",
        AssetType.research_share: "cmdb_ci_file_system",
        AssetType.storage_volume: "cmdb_ci_storage_volume",
    }

    STATUS_MAP = {
        "active": "1",
        "provisioning": "6",
        "decommissioning": "7",
        "decommissioned": "2",
        "read_only": "1",
    }

    STATE_MAP = {
        "submitted": "1",        # Open
        "pending_approval": "2",  # Work in Progress
        "approved": "2",
        "provisioning": "2",
        "completed": "3",         # Closed Complete
        "failed": "4",           # Closed Incomplete
        "cancelled": "7",        # Cancelled
    }

    def __init__(self):
        self.instance = os.getenv("SERVICENOW_INSTANCE", "")
        self.user = os.getenv("SERVICENOW_USER", "")
        self.password = os.getenv("SERVICENOW_PASSWORD", "")
        self.base_url = f"https://{self.instance}/api/now"

    def _client(self) -> httpx.Client:
        return httpx.Client(
            base_url=self.base_url,
            auth=(self.user, self.password),
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            timeout=30.0,
        )

    def create_request(self, request: ServiceRequest) -> dict:
        """Create a Request Item (RITM) in ServiceNow."""
        payload = {
            "short_description": f"[pdgeek.io] {request.request_type.value}: {request.payload.get('vm_name') or request.payload.get('share_name', 'N/A')}",
            "description": (
                f"Request ID: {request.id}\n"
                f"Type: {request.request_type.value}\n"
                f"Requestor: {request.requestor_name} ({request.requestor_email})\n"
                f"Department: {request.department}\n"
                f"Payload: {request.payload}"
            ),
            "caller_id": request.requestor_email,
            "category": "Infrastructure",
            "subcategory": request.request_type.value,
            "assignment_group": os.getenv("SERVICENOW_ASSIGNMENT_GROUP", "IT Infrastructure"),
            "u_pdgeek_request_id": request.id,
        }

        try:
            with self._client() as client:
                resp = client.post("/table/sc_req_item", json=payload)
                resp.raise_for_status()
                data = resp.json().get("result", {})
                request.itsm_ticket_id = data.get("number", "")
                logger.info(f"ServiceNow RITM created: {request.itsm_ticket_id}")
                return data
        except Exception as e:
            logger.error(f"ServiceNow create_request failed: {e}")
            return {"error": str(e)}

    def update_request(self, request: ServiceRequest) -> dict:
        """Update a Request Item in ServiceNow."""
        if not request.itsm_ticket_id:
            return {"skipped": "No ITSM ticket ID"}

        payload = {
            "state": self.STATE_MAP.get(request.status.value, "1"),
            "work_notes": f"[pdgeek.io] Status: {request.status.value}",
        }
        if request.cmdb_asset_id:
            payload["work_notes"] += f" | Asset: {request.cmdb_asset_id}"

        try:
            with self._client() as client:
                # Look up sys_id by number
                resp = client.get(
                    "/table/sc_req_item",
                    params={"sysparm_query": f"number={request.itsm_ticket_id}", "sysparm_limit": 1},
                )
                resp.raise_for_status()
                results = resp.json().get("result", [])
                if not results:
                    return {"error": f"RITM {request.itsm_ticket_id} not found"}

                sys_id = results[0]["sys_id"]
                resp = client.patch(f"/table/sc_req_item/{sys_id}", json=payload)
                resp.raise_for_status()
                return resp.json().get("result", {})
        except Exception as e:
            logger.error(f"ServiceNow update_request failed: {e}")
            return {"error": str(e)}

    def create_ci(self, asset: CMDBAsset) -> dict:
        """Create a Configuration Item in ServiceNow CMDB."""
        table = self.CI_CLASS_MAP.get(asset.asset_type, "cmdb_ci")

        payload = {
            "name": asset.name,
            "operational_status": "1" if asset.status.value == "active" else "6",
            "department": asset.department,
            "owned_by": asset.owner_email,
            "short_description": f"[pdgeek.io] {asset.asset_type.value}: {asset.name}",
            "u_pdgeek_asset_id": asset.id,
            "u_cost_center": asset.cost_center or "",
            "u_grant_id": asset.grant_id or "",
        }

        # Add type-specific attributes
        if asset.asset_type == AssetType.virtual_machine:
            payload["ip_address"] = asset.attributes.get("ip_address", "")
            payload["u_catalog_item"] = asset.attributes.get("catalog_item", "")
        elif asset.asset_type == AssetType.research_share:
            payload["u_nfs_path"] = asset.attributes.get("nfs_path", "")
            payload["u_quota_gb"] = str(asset.attributes.get("quota_gb", ""))
            payload["u_data_classification"] = asset.attributes.get("data_classification", "")

        try:
            with self._client() as client:
                resp = client.post(f"/table/{table}", json=payload)
                resp.raise_for_status()
                data = resp.json().get("result", {})
                asset.itsm_ci_sys_id = data.get("sys_id", "")
                asset.itsm_ci_id = data.get("name", "")
                logger.info(f"ServiceNow CI created: {asset.itsm_ci_sys_id}")
                return data
        except Exception as e:
            logger.error(f"ServiceNow create_ci failed: {e}")
            return {"error": str(e)}

    def update_ci(self, asset: CMDBAsset) -> dict:
        """Update a CI in ServiceNow CMDB."""
        if not asset.itsm_ci_sys_id:
            return {"skipped": "No ServiceNow sys_id"}

        table = self.CI_CLASS_MAP.get(asset.asset_type, "cmdb_ci")

        payload = {
            "operational_status": self.STATUS_MAP.get(asset.status.value, "1"),
            "u_cost_center": asset.cost_center or "",
        }
        if asset.monthly_cost is not None:
            payload["u_monthly_cost"] = str(asset.monthly_cost)

        try:
            with self._client() as client:
                resp = client.patch(f"/table/{table}/{asset.itsm_ci_sys_id}", json=payload)
                resp.raise_for_status()
                return resp.json().get("result", {})
        except Exception as e:
            logger.error(f"ServiceNow update_ci failed: {e}")
            return {"error": str(e)}

    def close_request(self, request: ServiceRequest) -> dict:
        """Close a ServiceNow request."""
        request.status.value  # just to reference
        return self.update_request(request)
