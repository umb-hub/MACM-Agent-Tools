"""
MACM Database Validation Checker
Validates MACM models by attempting to load them into Neo4j database
"""

import asyncio
from typing import Dict, Any, Optional
from datetime import datetime

from .base import BaseChecker
from core.models.base import ArchitectureModel
from core.models.validation import ValidationResult
from connectors.neo4j import Neo4jConnector


class MacmDatabaseChecker(BaseChecker):
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
    
    def _extract_trigger_error(self, error_message: str) -> str:
        """
        Extract meaningful error message from Neo4j trigger error
        
        Focuses on extracting detailed validation errors and ignores generic 
        "transaction terminated" messages from subsequent triggers.
        
        Example input:
        "{message: Error executing triggers {01_check_asset_type_labels=Failed to invoke procedure `apoc.util.validate`: Caused by: java.lang.RuntimeException: Asset type label validation failed:\n\nNode validation errors for component_id: 2:\n  1. /* ... */\n  2. /* ... */, 04_check_alternate_path_for_uses=The transaction has been terminated...}}"
        
        Example output:
        "Asset type label validation failed:\n\nNode validation errors for component_id: 2:\n  1. /* ... */\n  2. /* ... */ (from trigger: 01_check_asset_type_labels)"
        """
        import re
        
        # First, try to find detailed validation errors (multi-line with actual error content)
        # Pattern to match the first meaningful RuntimeException message and stop before the next trigger
        detailed_pattern = r'([^=,{]+)=.*?RuntimeException: (.*?)(?=,\s*\d+_\w+_|$|\})'
        
        match = re.search(detailed_pattern, error_message, re.DOTALL)
        
        if match:
            trigger_name = match.group(1).strip()
            error_text = match.group(2).strip()
            
            # Skip if this is just a "transaction terminated" message
            if "The transaction has been terminated" not in error_text and len(error_text) > 20:
                # Clean up the error text by removing unnecessary escape sequences
                error_text = error_text.replace('\\n', '\n').replace('\\"', '"')
                
                # Remove any trailing commas, braces, or whitespace
                error_text = re.sub(r'[,\}]+$', '', error_text).strip()
                
                return f"{error_text} (from trigger: {trigger_name})"
        
        # Fallback: Pattern to match trigger error format with /* */ comments
        trigger_pattern = r'Error executing triggers \{([^=]+)=.*?RuntimeException: /\*([^*]+)\*/\}'
        match = re.search(trigger_pattern, error_message)
        
        if match:
            trigger_name = match.group(1).strip()
            error_text = match.group(2).strip()
            return f"{error_text} (from trigger: {trigger_name})"
        
        # Another fallback: try to extract just the RuntimeException message with /* */
        runtime_pattern = r'RuntimeException: /\*([^*]+)\*/'
        runtime_match = re.search(runtime_pattern, error_message)
        if runtime_match:
            return runtime_match.group(1).strip()
        
        # If no meaningful pattern matches, return a cleaned version of the original error
        # Remove the outer braces and code/message wrapper
        cleaned = re.sub(r'^\{code: [^}]+\} \{message: ', '', error_message)
        cleaned = re.sub(r'\}+$', '', cleaned)
        return cleaned if cleaned != error_message else error_message
    
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
            # Attempt to load model into database (cleanup is handled automatically)
            success, errors = await self.connector.test_model_load(model)
            
            if success:
                # Model was loaded successfully and cleaned up automatically
                # Note: Using add_warning for informational message since add_info doesn't exist
                summary = {
                    "nodes_tested": len(model.nodes),
                    "relationships_tested": len(model.relationships),
                    "validation_time": datetime.now().isoformat(),
                    "status": "Model successfully validated against MACM database"
                }
            else:
                # Model failed to load due to triggers/constraints - this is expected for invalid models
                # Parse and categorize errors
                for error in errors:
                    if "trigger" in error.lower() or "executing triggers" in error.lower():
                        # Extract meaningful error message from trigger error
                        clean_error = self._extract_trigger_error(error)
                        self.add_error(clean_error)
                    elif "constraint" in error.lower():
                        self.add_error(f"MACM constraint validation failed: {error}")
                    elif "cleanup error" in error.lower():
                        self.add_warning(f"Database cleanup issue: {error}")
                
                summary = {
                    "nodes_tested": len(model.nodes),
                    "relationships_tested": len(model.relationships),
                    "error_count": len([e for e in errors if "cleanup error" not in e.lower()]),
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