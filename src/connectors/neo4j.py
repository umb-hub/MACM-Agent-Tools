"""
Neo4j Database Connector
Connector for reading/writing MACM models from/to Neo4j graph database
"""

import asyncio
from typing import List, Dict, Any, Optional
from neo4j import AsyncGraphDatabase, AsyncDriver

from .base import BaseConnector
from core.models.base import ArchitectureModel, Node, Relationship
from core.utils.cypher import architecture_model_to_cypher


class Neo4jConnector(BaseConnector):
    """Neo4j database connector for MACM models"""
    
    def __init__(self, connection_config: Dict[str, Any]):
        """
        Initialize Neo4j connector
        
        Expected config:
        {
            "uri": "bolt://localhost:7687",
            "user": "neo4j",
            "password": "password",
            "database": "neo4j"
        }
        """
        super().__init__(connection_config)
        self.driver: Optional[AsyncDriver] = None
        self.database = connection_config.get("database", "neo4j")
    
    async def connect(self) -> bool:
        """Establish connection to Neo4j database"""
        try:
            self.driver = AsyncGraphDatabase.driver(
                self.config["uri"],
                auth=(self.config["user"], self.config["password"])
            )
            
            # Test connection
            async with self.driver.session(database=self.database) as session:
                result = await session.run("RETURN 1 as test")
                await result.single()
            
            self.connected = True
            return True
        except Exception as e:
            print(f"Failed to connect to Neo4j: {e}")
            self.connected = False
            return False
    
    async def disconnect(self) -> bool:
        """Close connection to Neo4j database"""
        try:
            if self.driver:
                await self.driver.close()
            self.connected = False
            return True
        except Exception as e:
            print(f"Error disconnecting from Neo4j: {e}")
            return False
    
    async def read_model(self) -> ArchitectureModel:
        """Read architecture model from Neo4j"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        async with self.driver.session(database=self.database) as session:
            # Read nodes
            nodes_query = """
            MATCH (n:Component)
            RETURN n.component_id as component_id, n.name as name, n.type as type,
                   n.primary_label as primary_label, n.secondary_label as secondary_label
            """
            nodes_result = await session.run(nodes_query)
            nodes_data = await nodes_result.data()
            
            nodes = [
                Node(
                    component_id=record["component_id"],
                    name=record["name"],
                    type=record["type"],
                    primary_label=record.get("primary_label"),
                    secondary_label=record.get("secondary_label")
                )
                for record in nodes_data
            ]
            
            # Read relationships
            rels_query = """
            MATCH (source:Component)-[r]->(target:Component)
            RETURN source.name as source, target.name as target, 
                   type(r) as type, r.protocol as protocol, r.protocol_data as protocol_data
            """
            rels_result = await session.run(rels_query)
            rels_data = await rels_result.data()
            
            relationships = []
            for record in rels_data:
                protocol_value = record.get("protocol")
                protocol_data = record.get("protocol_data")
                
                # If we have structured protocol data, parse it
                if protocol_data:
                    try:
                        import json
                        from core.models.base import ProtocolStack
                        protocol_dict = json.loads(protocol_data)
                        protocol_value = ProtocolStack(**protocol_dict)
                    except (json.JSONDecodeError, TypeError, ValueError):
                        # Fall back to simple string protocol
                        protocol_value = protocol_value
                
                relationships.append(Relationship(
                    source=record["source"],
                    target=record["target"],
                    type=record["type"],
                    protocol=protocol_value
                ))
            
            return ArchitectureModel(nodes=nodes, relationships=relationships)
    
    async def write_model(self, model: ArchitectureModel) -> bool:
        """Write architecture model to Neo4j using cypher utility"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        try:
            async with self.driver.session(database=self.database) as session:
                # Generate Cypher CREATE statement using utility function
                cypher_query = architecture_model_to_cypher(model, format_style="multiline")
                
                # Execute the cypher query
                await session.run(cypher_query)
                
                return True
        except Exception as e:
            print(f"Error writing model to Neo4j: {e}")
            return False
    
    async def list_models(self) -> Dict[str, Any]:
        """Get information about the architecture model in Neo4j"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        async with self.driver.session(database=self.database) as session:
            query = """
            MATCH (n:Component)
            RETURN count(n) as node_count,
                   collect(DISTINCT n.type) as node_types
            """
            result = await session.run(query)
            data = await result.single()
            
            if data:
                return {
                    "node_count": data["node_count"],
                    "node_types": data["node_types"]
                }
            else:
                return {
                    "node_count": 0,
                    "node_types": []
                }
    
    async def test_model_load(self, model: ArchitectureModel) -> tuple[bool, List[str]]:
        """Test loading a model to validate it against Neo4j triggers and constraints"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        errors = []
        try:
            async with self.driver.session(database=self.database) as session:
                # Generate Cypher CREATE statement
                cypher_query = architecture_model_to_cypher(model, format_style="multiline")

                print("Testing model load with Cypher:")
                print(cypher_query)
                
                # Use proper async transaction pattern
                tx = await session.begin_transaction()
                try:
                    await tx.run(cypher_query)
                    await tx.commit()
                except Exception as e:
                    error_msg = str(e)
                    errors.append(error_msg)
                    await tx.rollback()
                    raise
                finally:
                    await tx.close()

                # If we get here, the model loaded successfully
                return True, errors
                
        except Exception as e:
            error_msg = str(e)
            errors.append(error_msg)
            return False, errors
        finally:
            # Always clean up test data
            try:
                async with self.driver.session(database=self.database) as session:
                    await session.run("MATCH (n) DETACH DELETE n")
            except Exception as cleanup_error:
                errors.append(f"Cleanup error: {cleanup_error}")
    
    def validate_config(self) -> bool:
        """Validate Neo4j connector configuration"""
        required_fields = ["uri", "user", "password"]
        return all(field in self.config for field in required_fields)