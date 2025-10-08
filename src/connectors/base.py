"""
Base Connector Interface
Abstract base class for all MACM data connectors
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional
from core.models.base import ArchitectureModel, Node, Relationship


class BaseConnector(ABC):
    """Abstract base class for all data connectors"""
    
    def __init__(self, connection_config: Dict[str, Any]):
        """Initialize connector with configuration"""
        self.config = connection_config
        self.connected = False
    
    @abstractmethod
    async def connect(self) -> bool:
        """Establish connection to data source"""
        pass
    
    @abstractmethod
    async def disconnect(self) -> bool:
        """Close connection to data source"""
        pass
    
    @abstractmethod
    async def read_model(self) -> ArchitectureModel:
        """Read architecture model from data source"""
        pass
    
    @abstractmethod
    async def write_model(self, model: ArchitectureModel) -> bool:
        """Write architecture model to data source"""
        pass
    
    @abstractmethod
    async def list_models(self) -> Dict[str, Any]:
        """Get information about architecture models in data source"""
        pass
    
    def validate_config(self) -> bool:
        """Validate connector configuration"""
        return self.config is not None
    
    def get_status(self) -> Dict[str, Any]:
        """Get connector status information"""
        return {
            "connected": self.connected,
            "config_valid": self.validate_config(),
            "connector_type": self.__class__.__name__
        }