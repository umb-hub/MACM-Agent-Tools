"""
Checkers API Module
Endpoints for syntax and semantic validation of architecture models
"""

from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any, Optional
import os

from core.models.base import ArchitectureModel
from core.models.validation import ValidationResult
from checkers.database import MacmDatabaseChecker
from checkers.database_v2 import MacmDatabaseCheckerV2
# Import other checkers if they exist
try:
    from checkers.syntax import SyntaxChecker
except ImportError:
    SyntaxChecker = None

try:
    from checkers.semantic import SemanticChecker
except ImportError:
    SemanticChecker = None

# Create router for checker endpoints
router = APIRouter(prefix="/checkers", tags=["checkers"])


@router.post("/syntax", response_model=ValidationResult, include_in_schema=SyntaxChecker is not None)
async def validate_syntax(model: ArchitectureModel):
    """
    Validate architecture model syntax against MACM rules
    Checks node types, relationship types, and structural constraints
    """
    if not SyntaxChecker:
        raise HTTPException(status_code=501, detail="Syntax checker not implemented")
    
    try:
        checker = SyntaxChecker()
        result = checker.validate(model)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Syntax validation error: {str(e)}")


@router.post("/semantic", response_model=ValidationResult, include_in_schema=SemanticChecker is not None)
async def validate_semantic(model: ArchitectureModel):
    """
    Validate semantic consistency of architecture model
    Checks type mappings, hosting constraints, and business rules
    """
    if not SemanticChecker:
        raise HTTPException(status_code=501, detail="Semantic checker not implemented")
    
    try:
        checker = SemanticChecker()
        result = checker.validate(model)
        return result
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Semantic validation error: {str(e)}")


@router.post("/database", response_model=ValidationResult)
async def validate_database(
    model: ArchitectureModel,
):
    """
    Validate architecture model against MACM database constraints and triggers
    Tests the model by attempting to load it into Neo4j database
    """
    try:
        # Get Neo4j configuration from environment variables or parameters
        neo4j_config = {
            "uri":  os.getenv("NEO4J_URI", "bolt://localhost:7687"),
            "user": os.getenv("NEO4J_USER", "neo4j"),
            "password": os.getenv("NEO4J_PASSWORD", "password"),
            "database": os.getenv("NEO4J_DATABASE", "neo4j")
        }
        
        # Validate required configuration
        if not all([neo4j_config["uri"], neo4j_config["user"], neo4j_config["password"]]):
            raise HTTPException(
                status_code=400, 
                detail="Neo4j configuration missing. Provide via environment variables (NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)"
            )
        
        # Create and run database checker
        checker = MacmDatabaseChecker(neo4j_config)
        
        try:
            result = await checker.validate_async(model)
            return result
        finally:
            # Always close the checker
            await checker.close()
            
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database validation error: {str(e)}")

@router.post("/database_v2", response_model=ValidationResult)
async def validate_database_v2(
    model: ArchitectureModel,
):
    """
    Validate architecture model against MACM database constraints and triggers
    Tests the model by attempting to load it into Neo4j database
    """
    try:
        # Get Neo4j configuration from environment variables or parameters
        neo4j_config = {
            "uri":  os.getenv("NEO4J_URI", "bolt://localhost:7687"),
            "user": os.getenv("NEO4J_USER", "neo4j"),
            "password": os.getenv("NEO4J_PASSWORD", "password"),
            "database": os.getenv("NEO4J_DATABASEV2", "neo4j")
        }
        
        # Validate required configuration
        if not all([neo4j_config["uri"], neo4j_config["user"], neo4j_config["password"]]):
            raise HTTPException(
                status_code=400, 
                detail="Neo4j configuration missing. Provide via environment variables (NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)"
            )
        
        # Create and run database checker
        checker = MacmDatabaseCheckerV2(neo4j_config)
        
        try:
            result = await checker.validate_async(model)
            return result
        finally:
            # Always close the checker
            await checker.close()
            
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database validation error: {str(e)}")



@router.get("/database/constraints")
async def get_database_constraints():
    """
    Get description of MACM database constraints for graph formalism
    Returns information about semantic and hosting rules enforced by the database
    """
    constraints = {
        "overview": "MACM Database Constraints for Graph Formalism",
        "description": "This document describes the semantic, hosting and syntax validation rules enforced by the MACM system to ensure architectural consistency, proper component relationships, and valid system configurations.",
        "syntax_constraints": {
            "required_node_properties": {
                "rule_id": "Rule 0",
                "category": "Syntax",
                "name": "Required Node Properties",
                "description": "Ensures all nodes include essential identifying properties with correct types and valid values",
                "rule": "1. Every node must have a `component_id` (string). 2. `component_id` must contain only digits and be > 0. 3. Every node must have a `primary_label` (string). 4. Every node must have a `type` (string).",
                "graph_pattern": "Node properties must include component_id, primary_label and type with expected formats",
                "rationale": "These properties uniquely identify nodes and enable reliable pattern matching for other rules",
                "violation_example": "A node without a component_id or with a non-numeric component_id"
            },
            "asset_type_labels": {
                "rule_id": "Rule 1",
                "category": "Syntax",
                "name": "Asset Type Labels",
                "description": "Validates primary and secondary labels based on the node type",
                "rule": "1. Primary label must match the first part of `type` (before the dot). 2. Nodes must include required secondary labels according to predefined mappings (e.g., HW->Server, SystemLayer->OS).",
                "graph_pattern": "Primary label equals substring of type before '.' and secondary labels belong to allowed lists",
                "rationale": "Correct labels ensure components can be classified and processed by semantic rules",
                "violation_example": "A node typed 'HW.Server' but labeled with primary label 'Service'"
            }
        },
        "semantic_constraints": {
            "service_hosting_requirements": {
                "rule_id": "Rule 2",
                "category": "Semantic",
                "name": "Single Host Incoming Requirement for Services",
                "description": "Every service component must have exactly one hosting incoming relationship to establish clear ownership and resource management",
                "rule": "Each Service node must have exactly one incoming relationship of type 'hosts' or 'provides' from another component.",
                "graph_pattern": "(Host)-[:hosts|provides]->(S:Service) and count of such incoming relationships for S == 1",
                "rationale": "Ensures accountability and avoids ambiguous ownership",
                "violation_example": "A service node with zero or multiple incoming 'hosts'/'provides' relationships"
            },
            "dependency_resilience": {
                "rule_id": "Rule 4",
                "category": "Semantic",
                "name": "Alternate Path Requirement for Dependencies",
                "description": "When a component depends on another via 'uses', there must be an alternate non-dependency path",
                "rule": "For every (A)-[:uses]->(B) there must exist at least one path between A and B composed only of non-'uses' relationships (hosts, provides, connects, interacts).",
                "graph_pattern": "If (A)-[:uses]->(B) exists then exists path (A)-[*]-(B) where no relationship in the path is of type 'uses'",
                "rationale": "Promotes resilience and prevents single points of failure",
                "violation_example": "A service that uses a database with no alternative hosting or network connectivity path"
            },
            "graph_connectivity": {
                "rule_id": "Rule 10",
                "category": "Semantic",
                "name": "Graph Connectivity",
                "description": "The architecture graph must be connected with no isolated nodes",
                "rule": "All nodes must be reachable from any arbitrary starting node when edges are considered undirected.",
                "graph_pattern": "Connected components count must be 1 for the model's node set",
                "rationale": "Ensures the model represents a cohesive system",
                "violation_example": "A set of nodes that are not connected to the main graph"
            },
            "system_layer_hierarchy": {
                "rule_id": "Rule 5",
                "category": "Specialized (Hosting)",
                "name": "Operating System Foundation for System Components",
                "description": "Only OS system layers may host other system layer components like container runtimes and hypervisors",
                "rule": "Only SystemLayer.OS nodes may host SystemLayer.ContainerRuntime or SystemLayer.HyperVisor nodes.",
                "graph_pattern": "(OS:SystemLayer {type: 'SystemLayer.OS'})-[:hosts]->(Target:SystemLayer) where Target.type in ['SystemLayer.ContainerRuntime','SystemLayer.HyperVisor']",
                "rationale": "Enforces correct system layer hierarchy",
                "violation_example": "A hypervisor directly hosting a container runtime without an OS intermediary"
            },
            "virtualization_model_enforcement": {
                "rule_id": "Rule 6",
                "category": "Specialized (Hosting)",
                "name": "Proper Virtualization Technology Pairing",
                "description": "Container runtimes host containers; hypervisors host VMs",
                "rule": "SystemLayer.ContainerRuntime can only host Virtual.Container; SystemLayer.HyperVisor can only host Virtual.VM.",
                "graph_patterns": [
                    "(ContainerRuntime:SystemLayer {type: 'SystemLayer.ContainerRuntime'})-[:hosts]->(Container:Virtual {type: 'Virtual.Container'})",
                    "(Hypervisor:SystemLayer {type: 'SystemLayer.HyperVisor'})-[:hosts]->(VM:Virtual {type: 'Virtual.VM'})"
                ],
                "rationale": "Prevents mismatched virtualization pairings",
                "violation_example": "A hypervisor hosting a container"
            },
            "service_hosting_restrictions": {
                "rule_id": "Rule 7",
                "category": "Specialized (Hosting)",
                "name": "Base System Layer Service Hosting",
                "description": "Services must be hosted by firmware or OS, not by higher-level virtualization platforms",
                "rule": "Only SystemLayer.Firmware and SystemLayer.OS may host Service nodes.",
                "graph_pattern": "(Base:SystemLayer {type: 'SystemLayer.Firmware'|'SystemLayer.OS'})-[:hosts]->(Service:Service)",
                "rationale": "Services need base system support rather than running directly on virtualization platforms",
                "violation_example": "A container runtime directly hosting a service"
            },
            "virtual_environment_limitations": {
                "rule_id": "Rule 8",
                "category": "Specialized (Hosting)",
                "name": "Virtual Environment Content Restrictions",
                "description": "Virtual environments should host only base system layers",
                "rule": "Virtual components may only host SystemLayer.OS or SystemLayer.Firmware.",
                "graph_pattern": "(Virtual)-[:hosts]->(BaseSystem:SystemLayer) where BaseSystem.type in ['SystemLayer.OS','SystemLayer.Firmware']",
                "rationale": "Prevents nested virtualization complexity",
                "violation_example": "A VM hosting a hypervisor"
            },
            "hardware_abstraction_requirements": {
                "rule_id": "Rule 9",
                "category": "Specialized (Hosting)",
                "name": "Proper Hardware Abstraction Layering",
                "description": "Hardware cannot directly host container runtimes; an OS must mediate",
                "rule": "Hardware nodes cannot host SystemLayer.ContainerRuntime directly.",
                "graph_pattern": "Forbidden: (Hardware:HW)-[:hosts]->(ContainerRuntime:SystemLayer {type: 'SystemLayer.ContainerRuntime'})",
                "rationale": "Maintains OS-level abstraction for container runtimes",
                "violation_example": "A physical server directly hosting a container runtime without an OS"
            }
        },
        "graph_formalism_concepts": {
            "node_types": "Components are represented as nodes with primary labels indicating their architectural category (HW for hardware, SystemLayer for system software, Virtual for virtualized components, Service for applications)",
            "relationship_semantics": "Connections between components use specific relationship types: 'hosts' indicates one component provides runtime environment for another, 'provides' indicates service provisioning, 'uses' indicates dependency relationships, 'connects' indicates network connectivity",
            "constraint_patterns": "Rules are expressed as graph patterns that must or must not exist, using Neo4j Cypher-like syntax to describe valid and invalid component relationships",
            "validation_approach": "Constraints are enforced through database triggers that execute pattern matching queries during component creation and modification to ensure architectural compliance"
        }
    }

    return constraints


@router.get("/database/test-connection", include_in_schema=False)
async def test_neo4j_connection(
    neo4j_uri: Optional[str] = None,
    neo4j_user: Optional[str] = None,
    neo4j_password: Optional[str] = None,
    neo4j_database: Optional[str] = None
):
    """
    Test Neo4j database connection
    Useful for verifying connection before running database validation
    """
    try:
        # Get Neo4j configuration from environment variables or parameters
        neo4j_config = {
            "uri": neo4j_uri or os.getenv("NEO4J_URI", "bolt://localhost:7687"),
            "user": neo4j_user or os.getenv("NEO4J_USER", "neo4j"),
            "password": neo4j_password or os.getenv("NEO4J_PASSWORD", "password"),
            "database": neo4j_database or os.getenv("NEO4J_DATABASE", "neo4j")
        }
        
        # Validate required configuration
        if not all([neo4j_config["uri"], neo4j_config["user"], neo4j_config["password"]]):
            raise HTTPException(
                status_code=400, 
                detail="Neo4j configuration missing. Provide via environment variables or request parameters"
            )
        
        # Test connection
        from connectors.neo4j import Neo4jConnector
        connector = Neo4jConnector(neo4j_config)
        
        try:
            connected = await connector.connect()
            if connected:
                return {
                    "status": "success",
                    "message": "Successfully connected to Neo4j database",
                    "config": {
                        "uri": neo4j_config["uri"],
                        "user": neo4j_config["user"],
                        "database": neo4j_config["database"]
                    }
                }
            else:
                raise HTTPException(status_code=503, detail="Failed to connect to Neo4j database")
        finally:
            if connector.connected:
                await connector.disconnect()
                
    except HTTPException:
        # Re-raise HTTP exceptions
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Connection test error: {str(e)}")


@router.post("/validate-all", include_in_schema=False)
async def validate_all(
    model: ArchitectureModel,
    neo4j_uri: Optional[str] = None,
    neo4j_user: Optional[str] = None,
    neo4j_password: Optional[str] = None,
    neo4j_database: Optional[str] = None,
    skip_syntax: bool = False,
    skip_semantic: bool = False,
    skip_database: bool = False
):
    """
    Run all available validation checks on the architecture model
    Returns combined results from syntax, semantic, and database validation
    """
    results = {
        "overall_valid": True,
        "checks_run": [],
        "syntax": None,
        "semantic": None,
        "database": None,
        "summary": {
            "total_errors": 0,
            "total_warnings": 0,
            "nodes_validated": len(model.nodes),
            "relationships_validated": len(model.relationships)
        }
    }
    
    try:
        # Run syntax validation
        if not skip_syntax and SyntaxChecker:
            try:
                checker = SyntaxChecker()
                syntax_result = checker.validate(model)
                results["syntax"] = syntax_result
                results["checks_run"].append("syntax")
                results["summary"]["total_errors"] += len(syntax_result.errors)
                results["summary"]["total_warnings"] += len(syntax_result.warnings)
                if not syntax_result.valid:
                    results["overall_valid"] = False
            except Exception as e:
                results["syntax"] = {"error": f"Syntax validation failed: {str(e)}"}
                results["overall_valid"] = False
        
        # Run semantic validation
        if not skip_semantic and SemanticChecker:
            try:
                checker = SemanticChecker()
                semantic_result = checker.validate(model)
                results["semantic"] = semantic_result
                results["checks_run"].append("semantic")
                results["summary"]["total_errors"] += len(semantic_result.errors)
                results["summary"]["total_warnings"] += len(semantic_result.warnings)
                if not semantic_result.valid:
                    results["overall_valid"] = False
            except Exception as e:
                results["semantic"] = {"error": f"Semantic validation failed: {str(e)}"}
                results["overall_valid"] = False
        
        # Run database validation
        if not skip_database:
            try:
                # Get Neo4j configuration
                neo4j_config = {
                    "uri": neo4j_uri or os.getenv("NEO4J_URI", "bolt://localhost:7687"),
                    "user": neo4j_user or os.getenv("NEO4J_USER", "neo4j"),
                    "password": neo4j_password or os.getenv("NEO4J_PASSWORD", "password"),
                    "database": neo4j_database or os.getenv("NEO4J_DATABASE", "neo4j")
                }
                
                if all([neo4j_config["uri"], neo4j_config["user"], neo4j_config["password"]]):
                    checker = MacmDatabaseChecker(neo4j_config)
                    try:
                        database_result = await checker.validate_async(model)
                        results["database"] = database_result
                        results["checks_run"].append("database")
                        results["summary"]["total_errors"] += len(database_result.errors)
                        results["summary"]["total_warnings"] += len(database_result.warnings)
                        if not database_result.valid:
                            results["overall_valid"] = False
                    finally:
                        await checker.close()
                else:
                    results["database"] = {"error": "Neo4j configuration missing - skipped database validation"}
                    
            except Exception as e:
                results["database"] = {"error": f"Database validation failed: {str(e)}"}
                results["overall_valid"] = False
        
        return results
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Validation error: {str(e)}")