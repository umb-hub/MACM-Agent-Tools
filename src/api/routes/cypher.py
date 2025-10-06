"""
Cypher API Module
Endpoints for converting MACM architecture models to Neo4j Cypher statements
"""

from fastapi import APIRouter, HTTPException
from typing import Optional

from core.models.base import ArchitectureModel
from core.utils.cypher import (
    architecture_model_to_cypher,
    generate_cypher_file,
    print_cypher_summary,
    nodes_to_cypher,
    relationships_to_cypher
)

# Create router for cypher endpoints
router = APIRouter(prefix="/cypher", tags=["cypher"])


@router.post("/convert")
async def convert_architecture_to_cypher(
    model: ArchitectureModel, 
    format_style: str = "multiline"
):
    """
    Convert architecture model to Neo4j Cypher CREATE statement
    
    Args:
        model: ArchitectureModel to convert
        format_style: "multiline" for readable format, "single" for single line
    """
    try:
        if format_style not in ["multiline", "single"]:
            raise HTTPException(status_code=400, detail="format_style must be 'multiline' or 'single'")
        
        cypher_statement = architecture_model_to_cypher(model, format_style)
        
        return {
            "success": True,
            "cypher": cypher_statement,
            "format": format_style,
            "summary": {
                "nodes_count": len(model.nodes),
                "relationships_count": len(model.relationships),
                "node_types": len(set(node.type for node in model.nodes)),
                "relationship_types": len(set(rel.type for rel in model.relationships)),
                "unique_node_names": len(set(node.name for node in model.nodes)),
                "protocols_used": len(set(
                    str(rel.protocol) for rel in model.relationships 
                    if rel.protocol is not None
                ))
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error converting to Cypher: {str(e)}")


@router.post("/convert/nodes")
async def convert_nodes_to_cypher(model: ArchitectureModel):
    """
    Convert only the nodes of an architecture model to Cypher CREATE statement
    """
    try:
        if not model.nodes:
            return {
                "success": True,
                "cypher": "// No nodes to create",
                "summary": {"nodes_count": 0}
            }
        
        cypher_statement = nodes_to_cypher(model.nodes)
        
        return {
            "success": True,
            "cypher": cypher_statement,
            "summary": {
                "nodes_count": len(model.nodes),
                "node_types": len(set(node.type for node in model.nodes))
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error converting nodes to Cypher: {str(e)}")


@router.post("/convert/relationships")
async def convert_relationships_to_cypher(model: ArchitectureModel):
    """
    Convert only the relationships of an architecture model to Cypher CREATE statement
    """
    try:
        if not model.relationships:
            return {
                "success": True,
                "cypher": "// No relationships to create",
                "summary": {"relationships_count": 0}
            }
        
        # Create node variable mapping for relationships
        node_var_map = {}
        for node in model.nodes:
            from core.utils.cypher import sanitize_node_name
            node_var_map[node.name] = sanitize_node_name(node.name)
        
        cypher_statement = relationships_to_cypher(model.relationships, node_var_map)
        
        return {
            "success": True,
            "cypher": cypher_statement,
            "summary": {
                "relationships_count": len(model.relationships),
                "relationship_types": len(set(rel.type for rel in model.relationships))
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error converting relationships to Cypher: {str(e)}")


@router.post("/generate/file")
async def generate_cypher_file_endpoint(
    model: ArchitectureModel,
    filename: Optional[str] = None
):
    """
    Generate a complete Cypher file for the architecture model
    
    Args:
        model: ArchitectureModel to convert
        filename: Optional filename (defaults to 'architecture_model.macm')
    """
    try:
        if not filename:
            filename = "architecture_model.macm"
        
        # Ensure .macm extension
        if not filename.endswith('.macm'):
            filename += '.macm'
        
        file_path = generate_cypher_file(model, filename)
        
        return {
            "success": True,
            "message": f"Cypher file generated successfully",
            "filename": filename,
            "file_path": file_path,
            "summary": {
                "nodes_count": len(model.nodes),
                "relationships_count": len(model.relationships),
                "file_size_bytes": len(architecture_model_to_cypher(model).encode('utf-8'))
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating Cypher file: {str(e)}")


@router.post("/validate")
async def validate_architecture_model(model: ArchitectureModel):
    """
    Validate architecture model for Cypher conversion compatibility
    """
    try:
        issues = []
        warnings = []
        
        # Check for nodes
        if not model.nodes:
            issues.append("Model has no nodes")
        
        # Check for duplicate node names
        node_names = [node.name for node in model.nodes]
        duplicate_names = set([name for name in node_names if node_names.count(name) > 1])
        if duplicate_names:
            issues.append(f"Duplicate node names found: {', '.join(duplicate_names)}")
        
        # Check for duplicate component IDs
        component_ids = [node.component_id for node in model.nodes]
        duplicate_ids = set([cid for cid in component_ids if component_ids.count(cid) > 1])
        if duplicate_ids:
            issues.append(f"Duplicate component IDs found: {', '.join(map(str, duplicate_ids))}")
        
        # Check relationships reference existing nodes
        existing_node_names = set(node.name for node in model.nodes)
        for rel in model.relationships:
            if rel.source not in existing_node_names:
                issues.append(f"Relationship source '{rel.source}' does not exist as a node")
            if rel.target not in existing_node_names:
                issues.append(f"Relationship target '{rel.target}' does not exist as a node")
        
        # Check for nodes without labels
        unlabeled_nodes = [node.name for node in model.nodes if not node.primary_label]
        if unlabeled_nodes:
            warnings.append(f"Nodes without primary labels: {', '.join(unlabeled_nodes)}")
        
        # Check for special characters in node names
        from core.utils.cypher import sanitize_node_name
        problematic_names = []
        for node in model.nodes:
            sanitized = sanitize_node_name(node.name)
            if sanitized != node.name.replace(' ', '_').replace('-', '_'):
                problematic_names.append(node.name)
        
        if problematic_names:
            warnings.append(f"Node names will be sanitized: {', '.join(problematic_names)}")
        
        is_valid = len(issues) == 0
        
        return {
            "valid": is_valid,
            "issues": issues,
            "warnings": warnings,
            "summary": {
                "nodes_count": len(model.nodes),
                "relationships_count": len(model.relationships),
                "issues_count": len(issues),
                "warnings_count": len(warnings)
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error validating model: {str(e)}")


@router.get("/info")
async def get_cypher_conversion_info():
    """
    Get information about Cypher conversion capabilities and options
    """
    return {
        "conversion_options": {
            "format_styles": ["multiline", "single"],
            "supported_features": [
                "Node labels and properties",
                "Relationship types and properties", 
                "Protocol stack conversion",
                "Name sanitization",
                "File generation",
                "Validation"
            ]
        },
        "endpoints": {
            "convert": "POST /cypher/convert - Convert full architecture model",
            "convert_nodes": "POST /cypher/convert/nodes - Convert only nodes",
            "convert_relationships": "POST /cypher/convert/relationships - Convert only relationships",
            "generate_file": "POST /cypher/generate/file - Generate .cypher file",
            "validate": "POST /cypher/validate - Validate model for conversion",
            "info": "GET /cypher/info - This endpoint"
        },
        "examples": {
            "node_format": "(NodeName:PrimaryLabel:SecondaryLabel {component_id: 1, name: 'Node Name', type: 'Node.Type'})",
            "relationship_format": "(Source)-[:RELATIONSHIP_TYPE {protocol: 'HTTP'}]->(Target)"
        }
    }