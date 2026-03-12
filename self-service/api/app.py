"""
pdgeek.io — Day 2 Operations API Gateway
ITSM-ready API for VM provisioning, research storage, CMDB, and chargeback.
Integrates with ServiceNow, TeamDynamix, and other ITSM platforms via
webhooks and REST adapters.
"""

import os
from pathlib import Path

import yaml
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from routers import catalog, requests, cmdb, chargeback, webhooks

app = FastAPI(
    title="pdgeek.io Operations API",
    description=(
        "ITSM-ready API gateway for Day 2 VMware operations. "
        "Supports VM provisioning, research storage (PowerScale), "
        "CMDB asset tracking, chargeback reporting, and ITSM webhook integration "
        "(ServiceNow, TeamDynamix, generic)."
    ),
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# --- Register Routers ---
app.include_router(catalog.router, prefix="/api/v1", tags=["Catalog"])
app.include_router(requests.router, prefix="/api/v1", tags=["Requests"])
app.include_router(cmdb.router, prefix="/api/v1", tags=["CMDB"])
app.include_router(chargeback.router, prefix="/api/v1", tags=["Chargeback"])
app.include_router(webhooks.router, prefix="/api/v1", tags=["Webhooks / ITSM"])


# --- Health ---

@app.get("/api/v1/health")
def health():
    return {
        "status": "healthy",
        "version": "2.0.0",
        "platform": "PowerEdge + PowerStore + PowerScale + VMware VVF/VCF",
        "project": "pdgeek.io",
        "integrations": {
            "itsm": os.getenv("ITSM_PROVIDER", "none"),
            "cmdb": "local",
        },
    }


# --- Mount static UI ---
ui_dir = Path(__file__).parent.parent / "ui"
if ui_dir.exists():
    app.mount("/", StaticFiles(directory=str(ui_dir), html=True), name="ui")
