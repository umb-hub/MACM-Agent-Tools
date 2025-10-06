"""
Neo4j Database Connector
Connector for reading/writing MACM models from/to Neo4j graph database
"""

import asyncio
from typing import List, Dict, Any, Optional
from neo4j import AsyncGraphDatabase, AsyncDriver

from .base import BaseConnector
from core.models.base import ArchitectureModel, Node, Relationship


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
    
    async def read_model(self, model_id: Optional[str] = None) -> ArchitectureModel:
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
                   type(r) as type, r.protocol as protocol
            """
            rels_result = await session.run(rels_query)
            rels_data = await rels_result.data()
            
            relationships = [
                Relationship(
                    source=record["source"],
                    target=record["target"],
                    type=record["type"],
                    protocol=record.get("protocol")
                )
                for record in rels_data
            ]
            
            return ArchitectureModel(nodes=nodes, relationships=relationships)
    
    async def write_model(self, model: ArchitectureModel, model_id: Optional[str] = None) -> bool:
        """Write architecture model to Neo4j"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        try:
            async with self.driver.session(database=self.database) as session:
                # Clear existing data if model_id is provided
                if model_id:
                    await session.run("MATCH (n:Component {model_id: $model_id}) DETACH DELETE n", 
                                    model_id=model_id)
                
                # Create nodes
                for node in model.nodes:
                    create_node_query = """
                    CREATE (n:Component {
                        component_id: $component_id,
                        name: $name,
                        type: $type,
                        primary_label: $primary_label,
                        secondary_label: $secondary_label,
                        model_id: $model_id
                    })
                    """
                    await session.run(create_node_query, 
                                    component_id=node.component_id,
                                    name=node.name,
                                    type=node.type,
                                    primary_label=node.primary_label,
                                    secondary_label=node.secondary_label,
                                    model_id=model_id or "default")
                
                # Create relationships
                for rel in model.relationships:
                    create_rel_query = f"""
                    MATCH (source:Component {{name: $source}})
                    MATCH (target:Component {{name: $target}})
                    CREATE (source)-[r:`{rel.type}` {{protocol: $protocol}}]->(target)
                    """
                    await session.run(create_rel_query,
                                    source=rel.source,
                                    target=rel.target,
                                    protocol=rel.protocol)
                
                return True
        except Exception as e:
            print(f"Error writing model to Neo4j: {e}")
            return False
    
    async def list_models(self) -> List[Dict[str, Any]]:
        """List available architecture models in Neo4j"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        async with self.driver.session(database=self.database) as session:
            query = """
            MATCH (n:Component)
            RETURN DISTINCT n.model_id as model_id, 
                   count(n) as node_count,
                   collect(DISTINCT n.type) as node_types
            """
            result = await session.run(query)
            data = await result.data()
            
            return [
                {
                    "model_id": record["model_id"],
                    "node_count": record["node_count"],
                    "node_types": record["node_types"]
                }
                for record in data
            ]
    
    async def delete_model(self, model_id: str) -> bool:
        """Delete architecture model from Neo4j"""
        if not self.connected or not self.driver:
            raise RuntimeError("Not connected to Neo4j database")
        
        try:
            async with self.driver.session(database=self.database) as session:
                query = "MATCH (n:Component {model_id: $model_id}) DETACH DELETE n"
                await session.run(query, model_id=model_id)
                return True
        except Exception as e:
            print(f"Error deleting model from Neo4j: {e}")
            return False
    
    def validate_config(self) -> bool:
        """Validate Neo4j connector configuration"""
        required_fields = ["uri", "user", "password"]
        return all(field in self.config for field in required_fields)