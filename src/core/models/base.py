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
    source: str = Field(description="Source component - can be a numeric string (component ID) or component name string")
    target: str = Field(description="Target component - can be a numeric string (component ID) or component name string")
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

    def __init__(self, **data):
        super().__init__(**data)
        self._component_id_map = {str(node.component_id): node for node in self.nodes}
        self._name_map = {node.name: node for node in self.nodes}
        # Convert relationship source/target from component_id (numeric string, possibly multiple digits) to component name
        for rel in self.relationships:
            # Convert source if it's a numeric string (multiple digits allowed) and matches a component_id
            if rel.source.isdigit() and rel.source in self._component_id_map:
                rel.source = self._component_id_map[rel.source].name
            # Convert target if it's a numeric string (multiple digits allowed) and matches a component_id
            if rel.target.isdigit() and rel.target in self._component_id_map:
                rel.target = self._component_id_map[rel.target].name
