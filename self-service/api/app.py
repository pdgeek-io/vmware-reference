"""
pdgeek.io — VMware Reference Architecture — Self-Service API
Lightweight FastAPI portal for VM provisioning.
"""

import os
import subprocess
from pathlib import Path

import yaml
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI(
    title="pdgeek.io Self-Service Portal",
    description="VM provisioning on PowerEdge + PowerStore + VMware VVF/VCF",
    version="1.0.0",
)

CATALOG_DIR = Path(__file__).parent.parent / "catalog"


class VMRequest(BaseModel):
    name: str
    catalog_item: str
    ip_address: str
    gateway: str = "10.0.200.1"
    dns_servers: list[str] = ["10.0.0.10"]


# --- Catalog Endpoints ---


@app.get("/api/v1/catalog")
def list_catalog():
    """List all available VM catalog items."""
    items = []
    for f in sorted(CATALOG_DIR.glob("*.yml")):
        with open(f) as fh:
            data = yaml.safe_load(fh)
        data["id"] = f.stem
        items.append(data)
    return {"catalog": items}


@app.get("/api/v1/catalog/{item_id}")
def get_catalog_item(item_id: str):
    """Get a specific catalog item definition."""
    path = CATALOG_DIR / f"{item_id}.yml"
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"Catalog item '{item_id}' not found")
    with open(path) as f:
        return yaml.safe_load(f)


# --- VM Provisioning ---


@app.post("/api/v1/vms", status_code=202)
def create_vm(request: VMRequest):
    """
    Request a new VM from the catalog.
    Triggers PowerCLI provisioning in the background.
    """
    # Validate catalog item exists
    catalog_path = CATALOG_DIR / f"{request.catalog_item}.yml"
    if not catalog_path.exists():
        raise HTTPException(status_code=404, detail=f"Catalog item '{request.catalog_item}' not found")

    with open(catalog_path) as f:
        catalog = yaml.safe_load(f)

    # Trigger PowerCLI in background
    powercli_cmd = [
        "pwsh", "-Command",
        f"Import-Module ../powercli/modules/PDGeekRef; "
        f"New-RefVM -Name '{request.name}' -CatalogItem '{request.catalog_item}' "
        f"-IPAddress '{request.ip_address}'"
    ]

    # In production, this would use a task queue (Celery, etc.)
    # For demo purposes, we fire-and-forget
    subprocess.Popen(powercli_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    return {
        "status": "provisioning",
        "vm_name": request.name,
        "catalog_item": catalog["name"],
        "ip_address": request.ip_address,
        "message": f"VM '{request.name}' is being provisioned from '{catalog['name']}'",
    }


# --- Health ---


@app.get("/api/v1/health")
def health():
    return {
        "status": "healthy",
        "platform": "PowerEdge + PowerStore + VMware VVF/VCF",
        "project": "pdgeek.io",
    }


# Mount static UI files
ui_dir = Path(__file__).parent.parent / "ui"
if ui_dir.exists():
    app.mount("/", StaticFiles(directory=str(ui_dir), html=True), name="ui")
