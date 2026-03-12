"""
pdgeek.io — Request and Asset Models
Pydantic models for ITSM request workflow and CMDB asset tracking.
"""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


# --- Request Workflow ---

class RequestStatus(str, Enum):
    submitted = "submitted"
    pending_approval = "pending_approval"
    approved = "approved"
    provisioning = "provisioning"
    completed = "completed"
    failed = "failed"
    cancelled = "cancelled"


class RequestType(str, Enum):
    vm = "vm"
    research_share = "research_share"
    chargeback_report = "chargeback_report"
    vm_removal = "vm_removal"


class VMProvisionRequest(BaseModel):
    catalog_item: str
    vm_name: str
    ip_address: str
    department: str
    requestor_email: str
    requestor_name: str
    gateway: str = "10.0.200.1"
    dns_servers: list[str] = ["10.0.0.10"]
    justification: Optional[str] = None
    # ITSM fields
    itsm_ticket_id: Optional[str] = None
    change_request_id: Optional[str] = None
    cost_center: Optional[str] = None


class ResearchShareRequest(BaseModel):
    share_name: str
    department: str
    pi_name: str
    pi_username: str
    pi_email: str
    grant_id: str
    grant_agency: str
    grant_expiration: str
    quota_gb: int = 1000
    data_classification: str = "controlled"
    compliance_flags: list[str] = []
    requestor_email: str
    requestor_name: str
    justification: Optional[str] = None
    irb_number: Optional[str] = None
    iacuc_number: Optional[str] = None
    cost_center: Optional[str] = None
    # ITSM fields
    itsm_ticket_id: Optional[str] = None
    change_request_id: Optional[str] = None


class ServiceRequest(BaseModel):
    id: str = Field(default_factory=lambda: "")
    request_type: RequestType
    status: RequestStatus = RequestStatus.submitted
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    requestor_name: str
    requestor_email: str
    department: str
    itsm_ticket_id: Optional[str] = None
    change_request_id: Optional[str] = None
    approver_email: Optional[str] = None
    approved_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    payload: dict = {}
    cmdb_asset_id: Optional[str] = None


class RequestUpdate(BaseModel):
    status: Optional[RequestStatus] = None
    approver_email: Optional[str] = None
    error_message: Optional[str] = None
    itsm_ticket_id: Optional[str] = None
    change_request_id: Optional[str] = None


# --- CMDB Assets ---

class AssetType(str, Enum):
    virtual_machine = "virtual_machine"
    research_share = "research_share"
    storage_volume = "storage_volume"


class AssetStatus(str, Enum):
    active = "active"
    provisioning = "provisioning"
    decommissioning = "decommissioning"
    decommissioned = "decommissioned"
    read_only = "read_only"


class CMDBAsset(BaseModel):
    id: str = Field(default_factory=lambda: "")
    asset_type: AssetType
    name: str
    status: AssetStatus = AssetStatus.active
    department: str
    owner_name: str
    owner_email: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    # Linkage
    request_id: Optional[str] = None
    itsm_ci_id: Optional[str] = None       # Configuration Item ID in ITSM
    itsm_ci_sys_id: Optional[str] = None   # ServiceNow sys_id or TDX asset ID
    # Attributes (flexible key-value for different asset types)
    attributes: dict = {}
    # Cost tracking
    cost_center: Optional[str] = None
    grant_id: Optional[str] = None
    monthly_cost: Optional[float] = None
    # Lifecycle
    expiration_date: Optional[str] = None
    last_audit_date: Optional[str] = None


class CMDBAssetUpdate(BaseModel):
    status: Optional[AssetStatus] = None
    attributes: Optional[dict] = None
    itsm_ci_id: Optional[str] = None
    itsm_ci_sys_id: Optional[str] = None
    cost_center: Optional[str] = None
    monthly_cost: Optional[float] = None
    expiration_date: Optional[str] = None
