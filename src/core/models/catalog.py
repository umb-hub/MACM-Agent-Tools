"""
Catalog Models
Models related to catalogs, asset types, and relationship patterns
"""

from pydantic import BaseModel
from typing import List, Optional
from .base import Node


class AssetType(BaseModel):
    """Asset type definition with description"""
    type: str
    description: str


class Protocol(BaseModel):
    """Protocol definition with detailed information"""
    name: str
    extended_name: Optional[str] = None
    description: str
    layer: str  # Data Link, Network, Transport, Session, Presentation, Application
    relationship: str  # connects, uses, etc.
    ports: List[str] = []  # List of port numbers or ranges


class RelationshipPattern(BaseModel):
    """Valid relationship pattern between asset types"""
    source: str
    type: str
    target: List[str]


class LabelAssignmentRequest(BaseModel):
    """Request to assign labels to nodes"""
    nodes: List[Node]


class LabelAssignmentResponse(BaseModel):
    """Response from label assignment operation"""
    success: bool
    labeled_nodes: List[Node] = []
    errors: List[str] = []