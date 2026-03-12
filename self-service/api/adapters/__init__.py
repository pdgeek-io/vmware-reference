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

_adapter_instance: Optional["BaseAdapter"] = None
_adapter_provider: Optional[str] = None


def get_adapter() -> Optional["BaseAdapter"]:
    """Return the configured ITSM adapter (cached singleton), or None if not configured."""
    global _adapter_instance, _adapter_provider

    provider = os.getenv("ITSM_PROVIDER", "").lower()

    # Return cached instance if provider hasn't changed
    if _adapter_instance is not None and provider == _adapter_provider:
        return _adapter_instance

    if provider == "servicenow":
        from .servicenow import ServiceNowAdapter
        _adapter_instance = ServiceNowAdapter()
    elif provider == "teamdynamix":
        from .teamdynamix import TeamDynamixAdapter
        _adapter_instance = TeamDynamixAdapter()
    elif provider == "generic":
        from .generic import GenericAdapter
        _adapter_instance = GenericAdapter()
    else:
        _adapter_instance = None

    _adapter_provider = provider
    return _adapter_instance
