"""
MACM Database Validation Checker
Validates MACM models by attempting to load them into Neo4j database
"""

import asyncio
from typing import Dict, Any, Optional
from pathlib import Path
from datetime import datetime

from .base import BaseChecker
from core.models.base import ArchitectureModel
from core.models.validation import ValidationResult
from connectors.neo4j import Neo4jConnector


class MacmDatabaseCheckerV3(BaseChecker):
    """
    Validates MACM architecture models by attempting to load them into Neo4j database
    
    This checker tests whether a model can be successfully loaded into the MACM Neo4j database
    by attempting to create all nodes and relationships. If Neo4j triggers or constraints
    detect issues, they will be captured as validation errors.
    """
    
    def __init__(self, neo4j_config: Dict[str, Any]):
        """
        Initialize MACM database checker
        
        Args:
            neo4j_config: Neo4j connection configuration
        """
        super().__init__()
        self.neo4j_config = neo4j_config
        self.connector = None
    
    async def _ensure_connection(self) -> bool:
        """Ensure Neo4j connection is established"""
        if not self.connector:
            self.connector = Neo4jConnector(self.neo4j_config)
        
        if not self.connector.connected:
            connected = await self.connector.connect()
            if not connected:
                self.add_error("Failed to connect to Neo4j database")
                return False
        
        return True
    
    async def validate_async(self, model: ArchitectureModel) -> ValidationResult:
        """
        Asynchronously validate architecture model against MACM database
        
        Args:
            model: ArchitectureModel to validate
            
        Returns:
            ValidationResult with success/failure and any trigger errors
        """
        self.reset()
        
        # Basic model validation
        if not model.nodes:
            self.add_error("Model has no nodes to validate")
            return self.create_result()
        
        if not model.relationships:
            self.add_warning("Model has no relationships")
        
        # Ensure database connection
        if not await self._ensure_connection():
            return self.create_result()
        
        try:
            # Upload model into database (we will run reporting queries against it)
            wrote = await self.connector.write_model(model)

            if not wrote:
                self.add_error("Failed to write model to Neo4j for reporting validation")
                return self.create_result()

            # Run reporting queries located in neo4j/queries in sorted order
            repo_root = Path(__file__).resolve().parents[2]
            queries_dir = repo_root / "neo4j" / "queries"
            violation_count = 0

            async with self.connector.driver.session(database=self.connector.database) as session:
                # Iterate files in deterministic order
                if queries_dir.exists():
                    for qf in sorted(queries_dir.glob("*.cypher")):
                        try:
                            query_text = qf.read_text()
                        except Exception as e:
                            self.add_warning(f"Could not read query file {qf.name}: {e}")
                            continue

                        try:
                            result = await session.run(query_text)
                            rows = await result.data()
                        except Exception as e:
                            # Query execution failed — record as error
                            self.add_error(f"Error running query {qf.name}: {e}")
                            continue
                        
                        if rows:
                            # Each row is a dict; format into readable strings
                            for r in rows:
                                try:
                                    if isinstance(r, dict):
                                        msg = "; ".join(f"{k}: {v}" for k, v in r.items())
                                    else:
                                        # neo4j returns records as dict-like objects
                                        msg = str(r)
                                except Exception:
                                    msg = str(r)
                                self.add_error(f"[{qf.name}] {msg}")
                                violation_count += 1

                else:
                    self.add_warning(f"Queries directory not found: {queries_dir}")

                # Cleanup test data
                try:
                    await session.run("MATCH (n) DETACH DELETE n")
                except Exception as cleanup_error:
                    self.add_warning(f"Database cleanup issue: {cleanup_error}")

            summary = {
                "nodes_tested": len(model.nodes),
                "relationships_tested": len(model.relationships),
                "violation_count": violation_count,
                "validation_time": datetime.now().isoformat()
            }
        
        except Exception as e:
            self.add_error(f"Unexpected error during database validation: {str(e)}")
            summary = {
                "nodes_tested": len(model.nodes),
                "relationships_tested": len(model.relationships),
                "validation_time": datetime.now().isoformat(),
                "error": str(e)
            }
        
        return self.create_result(summary)
    
    def validate(self, model: ArchitectureModel) -> ValidationResult:
        """
        Synchronous wrapper for async validation
        
        Args:
            model: ArchitectureModel to validate
            
        Returns:
            ValidationResult with success/failure and any trigger errors
        """
        # Create new event loop if none exists
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        try:
            if loop.is_running():
                # If loop is already running, we need to use a different approach
                import concurrent.futures
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    future = executor.submit(asyncio.run, self.validate_async(model))
                    return future.result()
            else:
                return loop.run_until_complete(self.validate_async(model))
        except Exception as e:
            self.reset()
            self.add_error(f"Error running async validation: {str(e)}")
            return self.create_result()
    
    async def close(self):
        """Close database connection"""
        if self.connector and self.connector.connected:
            await self.connector.disconnect()
    
    def __del__(self):
        """Cleanup on destruction"""
        try:
            if self.connector and self.connector.connected:
                # Try to close connection on destruction
                asyncio.create_task(self.connector.disconnect())
        except:
            pass  # Ignore errors during cleanup