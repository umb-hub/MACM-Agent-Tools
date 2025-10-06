"""
Base Models
Core data models used throughout the MACM Agent Tools
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any


class Node(BaseModel):
    """Architecture model node representing a system component"""
    component_id: int
    name: str
    type: str
    primary_label: Optional[str] = None
    secondary_label: Optional[str] = None


class Relationship(BaseModel):
    """Architecture model relationship between nodes"""
    source: str
    target: str
    type: str
    protocol: Optional[str] = None


class ArchitectureModel(BaseModel):
    """Complete architecture model with nodes and relationships"""
    nodes: List[Node]
    relationships: List[Relationship]