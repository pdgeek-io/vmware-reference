"""
pdgeek.io — Generic ITSM Adapter
Sends webhook notifications to any ITSM platform that accepts REST callbacks.
Works with Freshservice, Jira Service Management, Cherwell, or custom systems.

Required environment variables:
  GENERIC_ITSM_WEBHOOK_URL — URL to POST events to
  GENERIC_ITSM_API_KEY     — API key sent as Authorization header (optional)
"""

import os
import logging

import httpx

from .base import BaseAdapter
from models.requests import CMDBAsset, ServiceRequest

logger = logging.getLogger(__name__)


class GenericAdapter(BaseAdapter):
    def __init__(self):
        self.webhook_url = os.getenv("GENERIC_ITSM_WEBHOOK_URL", "")
        self.api_key = os.getenv("GENERIC_ITSM_API_KEY", "")

    def _client(self) -> httpx.Client:
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        return httpx.Client(headers=headers, timeout=30.0)

    def _send(self, event_type: str, data: dict) -> dict:
        """Send an event to the configured webhook URL."""
        if not self.webhook_url:
            logger.warning("GENERIC_ITSM_WEBHOOK_URL not set — skipping")
            return {"skipped": "No webhook URL configured"}

        payload = {
            "source": "pdgeek.io",
            "event_type": event_type,
            "data": data,
        }

        try:
            with self._client() as client:
                resp = client.post(self.webhook_url, json=payload)
                resp.raise_for_status()
                logger.info(f"Generic ITSM webhook sent: {event_type}")
                return {"sent": True, "status_code": resp.status_code}
        except Exception as e:
            logger.error(f"Generic ITSM webhook failed: {e}")
            return {"error": str(e)}

    def create_request(self, request: ServiceRequest) -> dict:
        return self._send("request.created", {
            "request_id": request.id,
            "type": request.request_type.value,
            "status": request.status.value,
            "requestor_name": request.requestor_name,
            "requestor_email": request.requestor_email,
            "department": request.department,
            "payload": request.payload,
        })

    def update_request(self, request: ServiceRequest) -> dict:
        return self._send("request.updated", {
            "request_id": request.id,
            "status": request.status.value,
            "cmdb_asset_id": request.cmdb_asset_id,
            "itsm_ticket_id": request.itsm_ticket_id,
        })

    def create_ci(self, asset: CMDBAsset) -> dict:
        return self._send("cmdb.asset.created", {
            "asset_id": asset.id,
            "asset_type": asset.asset_type.value,
            "name": asset.name,
            "status": asset.status.value,
            "department": asset.department,
            "owner_name": asset.owner_name,
            "owner_email": asset.owner_email,
            "attributes": asset.attributes,
            "grant_id": asset.grant_id,
            "cost_center": asset.cost_center,
            "monthly_cost": asset.monthly_cost,
        })

    def update_ci(self, asset: CMDBAsset) -> dict:
        return self._send("cmdb.asset.updated", {
            "asset_id": asset.id,
            "status": asset.status.value,
            "attributes": asset.attributes,
            "monthly_cost": asset.monthly_cost,
        })

    def close_request(self, request: ServiceRequest) -> dict:
        return self._send("request.closed", {
            "request_id": request.id,
            "status": request.status.value,
            "cmdb_asset_id": request.cmdb_asset_id,
        })
