"""
pdgeek.io — ITSM Adapters
Pluggable adapters for integrating with ITSM platforms.

Set ITSM_PROVIDER environment variable to activate:
  - "servicenow"  → ServiceNow REST API
  - "teamdynamix" → TeamDynamix REST API (common in higher ed)
  - "generic"     → Generic REST webhook adapter
  - unset/none    → No external ITSM (local only)
"""

import os
from typing import Optional


def get_adapter() -> Optional["BaseAdapter"]:
    """Return the configured ITSM adapter, or None if not configured."""
    provider = os.getenv("ITSM_PROVIDER", "").lower()

    if provider == "servicenow":
        from .servicenow import ServiceNowAdapter
        return ServiceNowAdapter()
    elif provider == "teamdynamix":
        from .teamdynamix import TeamDynamixAdapter
        return TeamDynamixAdapter()
    elif provider == "generic":
        from .generic import GenericAdapter
        return GenericAdapter()

    return None
