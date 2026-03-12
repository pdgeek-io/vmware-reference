"""
pdgeek.io — Catalog Router
Browse available service catalog items (VMs, research shares, compositions).
"""

from pathlib import Path

import yaml
from fastapi import APIRouter, HTTPException

router = APIRouter()
CATALOG_DIR = Path(__file__).parent.parent.parent / "catalog"


@router.get("/catalog")
def list_catalog():
    """List all available catalog items."""
    items = []
    for f in sorted(CATALOG_DIR.glob("*.yml")):
        with open(f) as fh:
            data = yaml.safe_load(fh)
        data["id"] = f.stem
        items.append(data)
    return {"catalog": items}


@router.get("/catalog/{item_id}")
def get_catalog_item(item_id: str):
    """Get a specific catalog item by ID."""
    path = CATALOG_DIR / f"{item_id}.yml"
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"Catalog item '{item_id}' not found")
    with open(path) as f:
        data = yaml.safe_load(f)
    data["id"] = item_id
    return data
