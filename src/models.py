"""
MACM Data Models
Pydantic models for API request/response schemas
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


class ValidationResult(BaseModel):
    """Result of validation checks (syntax or semantic)"""
    valid: bool
    errors: List[str] = []
    warnings: List[str] = []
    summary: Dict[str, Any] = {}


class LabelAssignmentRequest(BaseModel):
    """Request to assign labels to nodes"""
    nodes: List[Node]


class LabelAssignmentResponse(BaseModel):
    """Response from label assignment operation"""
    success: bool
    labeled_nodes: List[Node] = []
    errors: List[str] = []
    warnings: List[str] = []
    summary: Dict[str, int] = {}


class AssetType(BaseModel):
    """Asset type definition with description"""
    type: str
    description: str


class RelationshipPattern(BaseModel):
    """Valid relationship pattern between asset types"""
    source: str
    type: str
    target: List[str]