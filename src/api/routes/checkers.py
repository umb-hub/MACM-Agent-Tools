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
    neo4j_uri: Optional[str] = None,
    neo4j_user: Optional[str] = None,
    neo4j_password: Optional[str] = None,
    neo4j_database: Optional[str] = None
):
    """
    Validate architecture model against MACM database constraints and triggers
    Tests the model by attempting to load it into Neo4j database
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
                detail="Neo4j configuration missing. Provide via environment variables (NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD) or request parameters"
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


@router.get("/database/constraints")
async def get_database_constraints():
    """
    Get description of MACM database constraints for graph formalism
    Returns information about semantic and hosting rules enforced by the database
    """
    constraints = {
        "overview": "MACM Database Constraints for Graph Formalism",
        "description": "This document describes the semantic and hosting validation rules enforced by the MACM system to ensure architectural consistency, proper component relationships, and valid system configurations.",
        "semantic_constraints": {
            "service_hosting_requirements": {
                "name": "Single Host Requirement for Services",
                "description": "Every service component in the architecture must have exactly one hosting relationship to establish clear ownership and resource management",
                "rule": "Each Service node must have exactly one incoming relationship of type 'hosts' or 'provides' from another component",
                "graph_pattern": "In graph terms, for every Service node S, there must be exactly one relationship pattern: (Host)-[:hosts|provides]->(S:Service)",
                "rationale": "Services require a clear hosting relationship to establish accountability, resource management, and architectural clarity. Multiple hosts would create ambiguity about service ownership and management responsibility",
                "violation_example": "A web service that appears to be hosted by both a virtual machine and a container runtime simultaneously"
            },
            "dependency_resilience": {
                "name": "Alternate Path Requirement for Dependencies",
                "description": "When one component depends on another through a 'uses' relationship, there must be at least one alternative connection path that doesn't rely on dependency relationships",
                "rule": "For every 'uses' relationship between components A and B, there must exist at least one alternate path connecting A to B using only non-dependency relationships (hosts, provides, connects, interacts)",
                "graph_pattern": "If (A)-[:uses]->(B) exists, then there must also exist a path (A)-[*]-(B) where all relationships in the path are NOT of type 'uses'",
                "rationale": "This rule promotes architectural resilience by ensuring that dependencies don't create single points of failure. Alternative paths provide redundancy and fault tolerance in the system design",
                "violation_example": "A service that uses a database without any alternative connection path through hosting or network connectivity"
            },
            "system_layer_hierarchy": {
                "name": "Operating System Foundation for System Components",
                "description": "System layer components must follow a proper hierarchical structure where the operating system serves as the foundation for other system-level services",
                "rule": "Only operating system components (SystemLayer.OS) can host other system layer components, specifically container runtimes and hypervisors",
                "graph_pattern": "Valid pattern: (OS:SystemLayer {type: 'SystemLayer.OS'})-[:hosts]->(Target:SystemLayer) where Target.type in ['SystemLayer.ContainerRuntime', 'SystemLayer.HyperVisor']",
                "rationale": "Reflects the hierarchical nature of system software, where the operating system serves as the foundation for virtualization and containerization platforms",
                "violation_example": "A hypervisor attempting to directly host a container runtime without an operating system intermediary"
            },
            "virtualization_model_enforcement": {
                "name": "Proper Virtualization Technology Pairing",
                "description": "Virtual components must be hosted by their corresponding virtualization technology to maintain architectural consistency",
                "rule": "Container runtimes can only host containers, and hypervisors can only host virtual machines",
                "graph_patterns": [
                    "Valid: (ContainerRuntime:SystemLayer {type: 'SystemLayer.ContainerRuntime'})-[:hosts]->(Container:Virtual {type: 'Virtual.Container'})",
                    "Valid: (Hypervisor:SystemLayer {type: 'SystemLayer.HyperVisor'})-[:hosts]->(VM:Virtual {type: 'Virtual.VM'})"
                ],
                "rationale": "Enforces the proper virtualization model where container runtimes manage containers and hypervisors manage virtual machines, preventing architectural inconsistencies",
                "violation_example": "A hypervisor attempting to host a container, or a container runtime trying to host a virtual machine"
            },
            "service_hosting_restrictions": {
                "name": "Base System Layer Service Hosting",
                "description": "Services should be hosted directly by fundamental system components rather than by virtualization platforms",
                "rule": "Only firmware and operating system components can directly host services",
                "graph_pattern": "Valid: (BaseSystem:SystemLayer {type: 'SystemLayer.Firmware' | 'SystemLayer.OS'})-[:hosts]->(Service:Service)",
                "rationale": "Services should run on base system layers (firmware for embedded services, OS for application services) rather than on virtualization platforms, which should host virtual environments that then host services",
                "violation_example": "A container runtime directly hosting a web service instead of hosting a container that then runs the service"
            },
            "virtual_environment_limitations": {
                "name": "Virtual Environment Content Restrictions",
                "description": "Virtual environments should only contain fundamental system software to prevent excessive nesting and complexity",
                "rule": "Virtual machines and containers can only host basic system layers (operating systems and firmware)",
                "graph_pattern": "Valid: (Virtual:Virtual)-[:hosts]->(BaseSystem:SystemLayer) where BaseSystem.type in ['SystemLayer.OS', 'SystemLayer.Firmware']",
                "rationale": "Virtual environments should only contain base system software, not virtualization platforms themselves, preventing nested virtualization complexity and maintaining clear architectural boundaries",
                "violation_example": "A virtual machine hosting a hypervisor, creating nested virtualization scenarios"
            },
            "hardware_abstraction_requirements": {
                "name": "Proper Hardware Abstraction Layering",
                "description": "Hardware components must maintain proper abstraction layers and cannot directly host certain high-level system components",
                "rule": "Hardware nodes cannot directly host container runtimes, which must be mediated by an operating system",
                "graph_pattern": "Forbidden: (Hardware:HW)-[:hosts]->(ContainerRuntime:SystemLayer {type: 'SystemLayer.ContainerRuntime'})",
                "rationale": "Maintains proper software layering where container runtimes operate as operating system-level services, not as bare-metal software, ensuring correct architectural abstraction levels",
                "violation_example": "A server hardware component directly hosting a Docker container runtime without an operating system layer"
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