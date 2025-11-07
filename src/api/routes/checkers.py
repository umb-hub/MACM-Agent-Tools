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
from checkers.database_v3 import MacmDatabaseCheckerV3

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

@router.post("/database_v3", response_model=ValidationResult)
async def validate_database_v3(
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
        checker = MacmDatabaseCheckerV3(neo4j_config)
        
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
    # Compact, grouped constraints summary (prompt-ready)
    # Groups combine related rules with a brief underlying rationale
    constraints = {
        "title": "MACM database constraints",
         "summary": [
            {
                "name": "Node type & label validity",
                "short": "Primary label must match node type prefix; required properties: component_id, primary_label, type."
            },
            {
                "name": "Asset type secondary labels",
                "short": "Secondary labels must follow predefined mappings for each type (e.g., HW->Server, SystemLayer->OS)."
            },
            {
                "name": "Relationship pattern validity",
                "short": "Only allowed relation patterns between primary labels are permitted (e.g., Party-interacts-Service, SystemLayer-hosts-Virtual)."
            },
            {
                "name": "Graph connectivity",
                "short": "Model must be connected: no isolated nodes (all nodes reachable in undirected graph)."
            },
            {
                "name": "Single-host for SystemLayer",
                "short": "Each SystemLayer component must have exactly one incoming hosts/provides relationship."
            },
            {
                "name": "Single-host for Service",
                "short": "Each Service must have exactly one incoming hosts/provides relationship."
            },
            {
                "name": "Hosts acyclicity",
                "short": "The hosts hierarchy must be acyclic; cycles in :hosts relations are violations."
            },
            {
                "name": "Alternate path for uses",
                "short": "For every (A)-[:uses]->(B) there must exist an alternate path between A and B that does not use 'uses' relationships."
            },
            {
                "name": "HW -> SystemLayer restrictions",
                "short": "Hardware nodes cannot directly host SystemLayer.ContainerRuntime; an OS must mediate."
            },
            {
                "name": "SystemLayer -> SystemLayer hosting rules",
                "short": "Only specific SystemLayer types (e.g., OS) may host certain SystemLayer targets (ContainerRuntime, HyperVisor)."
            },
            {
                "name": "SystemLayer -> Virtual hosting rules",
                "short": "ContainerRuntime should host Virtual.Container; HyperVisor should host Virtual.VM."
            },
            {
                "name": "Virtual -> SystemLayer hosting rules",
                "short": "Virtual components may only host base SystemLayer nodes (OS or Firmware)."
            },
            {
                "name": "SystemLayer hosting for Services",
                "short": "Only SystemLayer.Firmware and SystemLayer.OS may host Service nodes."
            }
        ]
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