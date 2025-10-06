"""
Catalogs API Module
Endpoints for managing MACM catalogs (labels, asset types, relationships, protocols)
"""

from fastapi import APIRouter, HTTPException
from typing import List

from core.models.catalog import (
    LabelAssignmentRequest, 
    LabelAssignmentResponse, 
    AssetType, 
    RelationshipPattern
)
from core.models.base import Node
from core.utils.catalog import (
    load_asset_types,
    load_relationships,
    load_protocols,
    load_relationship_patterns,
    get_catalogs_info,
    assign_labels_to_node
)

# Create router for catalog endpoints
router = APIRouter(prefix="/catalogs", tags=["catalogs"])

# Load catalog data from CSV files
def get_asset_types():
    return load_asset_types()

def get_relationship_types():
    return load_relationships()

def get_relationship_patterns_data():
    return load_relationship_patterns()

def get_protocols_data():
    return load_protocols()


@router.post("/labels", response_model=LabelAssignmentResponse)
async def assign_labels(request: LabelAssignmentRequest):
    """Assign primary and secondary labels to nodes based on their asset types"""
    try:
        labeled_nodes = []
        errors = []
        warnings = []
        
        for node in request.nodes:
            try:
                labeled_node = node.copy()
                assign_labels_to_node(labeled_node)
                labeled_nodes.append(labeled_node)
                
                # Validate against known asset types
                asset_types = get_asset_types()
                if not any(at.type == node.type for at in asset_types):
                    warnings.append(f"Node {node.component_id}: type '{node.type}' not found in catalog")
                    
            except Exception as e:
                errors.append(f"Error processing node {node.component_id}: {str(e)}")
        
        return LabelAssignmentResponse(
            success=len(errors) == 0,
            labeled_nodes=labeled_nodes,
            errors=errors
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/asset_types", response_model=List[AssetType])
async def get_asset_types_endpoint():
    """Get valid asset types with descriptions"""
    return get_asset_types()


@router.get("/relationships", response_model=List[str])
async def get_relationships_endpoint():
    """Get available relationship types with descriptions"""
    return get_relationship_types()


@router.get("/relationship_pattern", response_model=List[RelationshipPattern])
async def get_relationship_patterns_endpoint():
    """Get valid relationship patterns between asset types"""
    return get_relationship_patterns_data()


@router.get("/protocols", response_model=List[str])
async def get_protocols_endpoint():
    """Get supported network protocols"""
    return get_protocols_data()


@router.get("/info")
async def get_catalogs_info_endpoint():
    """Get information about catalog files and their status"""
    return get_catalogs_info()