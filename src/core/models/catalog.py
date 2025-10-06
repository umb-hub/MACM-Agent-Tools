"""
Catalog Models
Models related to catalogs, asset types, and relationship patterns
"""

from pydantic import BaseModel
from typing import List
from .base import Node


class AssetType(BaseModel):
    """Asset type definition with description"""
    type: str
    description: str


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