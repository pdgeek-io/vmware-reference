"""
pdgeek.io — Base ITSM Adapter
Abstract interface that all ITSM adapters must implement.
"""

from abc import ABC, abstractmethod

from models.requests import CMDBAsset, ServiceRequest


class BaseAdapter(ABC):
    """Base class for ITSM platform adapters."""

    @abstractmethod
    def create_request(self, request: ServiceRequest) -> dict:
        """Create a service request/ticket in the ITSM platform."""
        ...

    @abstractmethod
    def update_request(self, request: ServiceRequest) -> dict:
        """Update a service request/ticket in the ITSM platform."""
        ...

    @abstractmethod
    def create_ci(self, asset: CMDBAsset) -> dict:
        """Create a Configuration Item in the ITSM CMDB."""
        ...

    @abstractmethod
    def update_ci(self, asset: CMDBAsset) -> dict:
        """Update a Configuration Item in the ITSM CMDB."""
        ...

    @abstractmethod
    def close_request(self, request: ServiceRequest) -> dict:
        """Close/resolve a service request in the ITSM platform."""
        ...
