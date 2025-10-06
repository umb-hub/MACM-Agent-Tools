"""
Base Models
Core data models used throughout the MACM Agent Tools
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any, Union


class ProtocolStack(BaseModel):
    """
    Protocol stack representation following OSI model layers
    Allows detailed specification of protocols at different network layers
    """
    data_link_protocol: Optional[str] = Field(None, description="Layer 2 - Data Link Protocol (e.g., Ethernet, Wi-Fi)")
    network_protocol: Optional[str] = Field(None, description="Layer 3 - Network Protocol (e.g., IP, IPv6)")
    transport_protocol: Optional[str] = Field(None, description="Layer 4 - Transport Protocol (e.g., TCP, UDP)")
    session_protocol: Optional[str] = Field(None, description="Layer 5 - Session Protocol (e.g., NetBIOS, RPC)")
    presentation_protocol: Optional[str] = Field(None, description="Layer 6 - Presentation Protocol (e.g., TLS, SSL)")
    application_protocol: Optional[str] = Field(None, description="Layer 7 - Application Protocol (e.g., HTTP, MQTT, gRPC)")
    
    # Additional protocol properties
    properties: Optional[Dict[str, Any]] = Field(None, description="Additional protocol-specific properties")


class Node(BaseModel):
    """Architecture model node representing a system component"""
    component_id: int
    name: str
    type: str
    primary_label: Optional[str] = None
    secondary_label: Optional[str] = None
    properties: Optional[Dict[str, Any]] = None


class Relationship(BaseModel):
    """Architecture model relationship between nodes"""
    source: str
    target: str
    type: str
    protocol: Optional[Union[str, ProtocolStack]] = Field(
        None, 
        description="Communication protocol - can be a simple string (backward compatibility) or detailed ProtocolStack"
    )
    properties: Optional[Dict[str, Any]] = None


class ArchitectureModel(BaseModel):
    """Complete architecture model with nodes and relationships"""
    nodes: List[Node]
    relationships: List[Relationship]