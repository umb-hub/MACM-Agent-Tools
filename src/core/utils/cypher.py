"""
Cypher Conversion Utilities
Functions to convert MACM Architecture Models to Neo4j Cypher CREATE statements
"""

from typing import List, Optional, Dict, Any
from core.models.base import ArchitectureModel, Node, Relationship, ProtocolStack


def sanitize_node_name(name: str) -> str:
    """
    Sanitize node name for use as Cypher variable name
    Replace spaces and special characters with underscores
    """
    # Replace spaces and special characters with underscores
    sanitized = name.replace(' ', '_').replace('-', '_').replace('.', '_')
    # Remove any other non-alphanumeric characters except underscores
    sanitized = ''.join(c if c.isalnum() or c == '_' else '_' for c in sanitized)
    # Ensure it doesn't start with a number
    if sanitized and sanitized[0].isdigit():
        sanitized = f"node_{sanitized}"
    return sanitized


def format_node_labels(node: Node) -> str:
    """
    Format node labels for Cypher CREATE statement
    Uses primary_label and secondary_label if available, otherwise falls back to type parsing
    """
    labels = []
    
    if node.primary_label:
        labels.append(node.primary_label)
    
    if node.secondary_label:
        labels.append(node.secondary_label)
    
    # If no labels are set, try to extract from type
    if not labels and node.type:
        if '.' in node.type:
            parts = node.type.split('.')
            labels.append(parts[0])
            if len(parts) > 1:
                labels.append(parts[1])
        else:
            labels.append(node.type)
    
    # Join labels with colons
    return ':'.join(labels) if labels else 'Component'


def format_node_properties(node: Node) -> str:
    """
    Format node properties for Cypher CREATE statement
    """
    properties = {
        'component_id': f"'{node.component_id}'",
        'name': f"'{node.name}'",
        'type': f"'{node.type}'"
    }
    
    if node.primary_label:
        properties['primary_label'] = f"'{node.primary_label}'"
    
    if node.secondary_label:
        properties['secondary_label'] = f"'{node.secondary_label}'"
    
    # Add any additional properties from the node.properties dict
    if node.properties:
        for key, value in node.properties.items():
            if isinstance(value, str):
                properties[key] = f"'{value}'"
            else:
                properties[key] = str(value)
    
    # Format as Cypher property map
    prop_pairs = [f"{key}: {value}" for key, value in properties.items()]
    return '{' + ', '.join(prop_pairs) + '}'


def format_relationship_properties(relationship: Relationship) -> str:
    """
    Format relationship properties for Cypher CREATE statement
    """
    properties = {}
    
    if relationship.protocol:
        if isinstance(relationship.protocol, ProtocolStack):
            # For ProtocolStack, use the application protocol as main protocol
            if relationship.protocol.application_protocol:
                properties['application_protocol'] = f"'{relationship.protocol.application_protocol}'"
            
            # Add detailed protocol information as separate properties
            if relationship.protocol.transport_protocol:
                properties['transport_protocol'] = f"'{relationship.protocol.transport_protocol}'"
            if relationship.protocol.presentation_protocol:
                properties['presentation_protocol'] = f"'{relationship.protocol.presentation_protocol}'"
            if relationship.protocol.network_protocol:
                properties['network_protocol'] = f"'{relationship.protocol.network_protocol}'"
            
            # Add any additional protocol properties
            if relationship.protocol.properties:
                for key, value in relationship.protocol.properties.items():
                    if isinstance(value, str):
                        properties[f"protocol_{key}"] = f"'{value}'"
                    else:
                        properties[f"protocol_{key}"] = str(value)
        else:
            # Simple string protocol
            properties['protocol'] = f"'{relationship.protocol}'"
    
    # Add any additional relationship properties
    if relationship.properties:
        for key, value in relationship.properties.items():
            if isinstance(value, str):
                properties[key] = f"'{value}'"
            else:
                properties[key] = str(value)
    
    if properties:
        prop_pairs = [f"{key}: {value}" for key, value in properties.items()]
        return '{' + ', '.join(prop_pairs) + '}'
    else:
        return '{}'


def architecture_model_to_cypher(model: ArchitectureModel, format_style: str = "multiline") -> str:
    """
    Convert ArchitectureModel to Cypher CREATE statement
    
    Args:
        model: ArchitectureModel to convert
        format_style: "multiline" for readable format, "single" for single line
    
    Returns:
        Cypher CREATE statement as string
    """
    if not model.nodes:
        return "// No nodes to create"
    
    # Create node variable mapping for relationships
    node_var_map = {}
    for node in model.nodes:
        var_name = sanitize_node_name(node.name)
        node_var_map[node.name] = var_name
    
    # Generate node CREATE statements
    node_statements = []
    for node in model.nodes:
        var_name = node_var_map[node.name]
        labels = format_node_labels(node)
        properties = format_node_properties(node)
        
        node_stmt = f"({var_name}:{labels} {properties})"
        node_statements.append(node_stmt)
    
    # Generate relationship CREATE statements
    relationship_statements = []
    for rel in model.relationships:
        source_var = node_var_map.get(rel.source)
        target_var = node_var_map.get(rel.target)
        
        if not source_var or not target_var:
            # Skip relationships where nodes don't exist
            continue
        
        properties = format_relationship_properties(rel)
        rel_stmt = f"({source_var})-[:{rel.type} {properties}]->({target_var})"
        relationship_statements.append(rel_stmt)
    
    # Combine all statements
    all_statements = node_statements + relationship_statements
    
    if format_style == "single":
        return "CREATE " + ", ".join(all_statements)
    else:
        # Multiline format
        if len(all_statements) == 1:
            return "CREATE " + all_statements[0]
        else:
            result = "CREATE " + all_statements[0]
            for stmt in all_statements[1:]:
                result += ",\n       " + stmt
            return result


def nodes_to_cypher(nodes: List[Node]) -> str:
    """
    Convert a list of nodes to Cypher CREATE statement
    """
    if not nodes:
        return "// No nodes to create"
    
    node_statements = []
    for node in nodes:
        var_name = sanitize_node_name(node.name)
        labels = format_node_labels(node)
        properties = format_node_properties(node)
        
        node_stmt = f"({var_name}:{labels} {properties})"
        node_statements.append(node_stmt)
    
    if len(node_statements) == 1:
        return "CREATE " + node_statements[0]
    else:
        result = "CREATE " + node_statements[0]
        for stmt in node_statements[1:]:
            result += ",\n       " + stmt
        return result


def relationships_to_cypher(relationships: List[Relationship], node_var_map: Dict[str, str] = None) -> str:
    """
    Convert a list of relationships to Cypher CREATE statement
    
    Args:
        relationships: List of relationships to convert
        node_var_map: Optional mapping of node names to variable names
    """
    if not relationships:
        return "// No relationships to create"
    
    if not node_var_map:
        # Create default mapping if not provided
        node_var_map = {}
        all_node_names = set()
        for rel in relationships:
            all_node_names.add(rel.source)
            all_node_names.add(rel.target)
        
        for name in all_node_names:
            node_var_map[name] = sanitize_node_name(name)
    
    relationship_statements = []
    for rel in relationships:
        source_var = node_var_map.get(rel.source, sanitize_node_name(rel.source))
        target_var = node_var_map.get(rel.target, sanitize_node_name(rel.target))
        
        properties = format_relationship_properties(rel)
        rel_stmt = f"({source_var})-[:{rel.type} {properties}]->({target_var})"
        relationship_statements.append(rel_stmt)
    
    if len(relationship_statements) == 1:
        return "CREATE " + relationship_statements[0]
    else:
        result = "CREATE " + relationship_statements[0]
        for stmt in relationship_statements[1:]:
            result += ",\n       " + stmt
        return result


def generate_cypher_file(model: ArchitectureModel, filename: str = "architecture_model.cypher") -> str:
    """
    Generate a complete Cypher file for the architecture model
    
    Args:
        model: ArchitectureModel to convert
        filename: Output filename
    
    Returns:
        File path where the Cypher was written
    """
    cypher_content = f"""// Architecture Model: {filename}
// Generated from MACM Agent Tools
// Date: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

// Clean up existing data (optional - uncomment if needed)
// MATCH (n) DETACH DELETE n;

// Create architecture components and relationships
{architecture_model_to_cypher(model)}
"""
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(cypher_content)
    
    return filename


def print_cypher_summary(model: ArchitectureModel) -> None:
    """
    Print a summary of the Cypher conversion
    """
    print(f"Cypher Conversion Summary:")
    print(f"- Nodes: {len(model.nodes)}")
    print(f"- Relationships: {len(model.relationships)}")
    print(f"- Node types: {len(set(node.type for node in model.nodes))}")
    print(f"- Relationship types: {len(set(rel.type for rel in model.relationships))}")
    
    # Print node type distribution
    node_types = {}
    for node in model.nodes:
        primary_label = node.primary_label or node.type.split('.')[0] if '.' in node.type else node.type
        node_types[primary_label] = node_types.get(primary_label, 0) + 1
    
    print(f"\nNode distribution by primary label:")
    for label, count in sorted(node_types.items()):
        print(f"  {label}: {count}")
    
    # Print relationship type distribution
    rel_types = {}
    for rel in model.relationships:
        rel_types[rel.type] = rel_types.get(rel.type, 0) + 1
    
    print(f"\nRelationship distribution by type:")
    for rel_type, count in sorted(rel_types.items()):
        print(f"  {rel_type}: {count}")