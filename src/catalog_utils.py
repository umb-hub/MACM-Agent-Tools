"""
CSV Utilities for MACM Catalogs
Functions to read and parse catalog CSV files
"""

import csv
import os
from typing import List, Dict, Any
from pathlib import Path

from models import AssetType, RelationshipPattern

# Get the project root directory
PROJECT_ROOT = Path(__file__).parent.parent
CATALOGS_DIR = PROJECT_ROOT / "catalogs"


def read_csv_file(filename: str) -> List[Dict[str, str]]:
    """Read a CSV file and return list of dictionaries"""
    filepath = CATALOGS_DIR / filename
    
    if not filepath.exists():
        raise FileNotFoundError(f"Catalog file not found: {filepath}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as csvfile:
            # Try semicolon delimiter first, then comma
            content = csvfile.read()
            csvfile.seek(0)
            
            if ';' in content.split('\n')[0]:
                reader = csv.DictReader(csvfile, delimiter=';')
            else:
                reader = csv.DictReader(csvfile)
            return list(reader)
    except Exception as e:
        raise Exception(f"Error reading {filename}: {str(e)}")


def load_asset_types() -> List[AssetType]:
    """Load asset types from CSV file"""
    data = read_csv_file("asset_types.csv")
    return [AssetType(type=row['AssetType'], description=row['Description']) for row in data]


def load_relationships() -> List[str]:
    """Load relationship types from CSV file"""
    data = read_csv_file("relationships.csv")
    return [f"{row['type']}: {row['description']}" for row in data]


def load_protocols() -> List[str]:
    """Load protocols from CSV file"""
    data = read_csv_file("protocols.csv")
    return [row['Name'] for row in data]


def load_relationship_patterns() -> List[RelationshipPattern]:
    """Load relationship patterns from CSV file"""
    data = read_csv_file("relationship_patterns.csv")
    
    # Group by source and relationship_type to create array structure
    patterns_dict = {}
    for row in data:
        key = (row['source'], row['relationship_type'])
        if key not in patterns_dict:
            patterns_dict[key] = []
        patterns_dict[key].append(row['target'])
    
    # Convert to RelationshipPattern objects
    patterns = []
    for (source, rel_type), targets in patterns_dict.items():
        patterns.append(RelationshipPattern(
            source=source,
            type=rel_type,
            target=targets
        ))
    
    return patterns


def assign_labels_to_node(node) -> None:
    """Assign primary and secondary labels based on node type by matching against asset types CSV"""
    try:
        # Load asset types from CSV to find matching labels
        asset_data = read_csv_file("asset_types.csv")
        
        # Find matching asset type in CSV
        for row in asset_data:
            if row['AssetType'] == node.type:
                node.primary_label = row['Primary Label']
                node.secondary_label = row['Secondary Label'] if row['Secondary Label'] else None
                return
        
        # If no match found, fall back to splitting by "."
        if "." in node.type:
            primary, secondary = node.type.split(".", 1)
            node.primary_label = primary
            node.secondary_label = secondary
        else:
            node.primary_label = node.type
            node.secondary_label = None
            
    except Exception as e:
        # If CSV reading fails, fall back to splitting
        if "." in node.type:
            primary, secondary = node.type.split(".", 1)
            node.primary_label = primary
            node.secondary_label = secondary
        else:
            node.primary_label = node.type
            node.secondary_label = None


def get_catalogs_info() -> Dict[str, Any]:
    """Get information about available catalog files"""
    info = {
        "catalogs_directory": str(CATALOGS_DIR),
        "available_files": [],
        "file_status": {}
    }
    
    expected_files = ["asset_types.csv", "relationships.csv", "protocols.csv", "relationship_patterns.csv"]
    
    for filename in expected_files:
        filepath = CATALOGS_DIR / filename
        if filepath.exists():
            info["available_files"].append(filename)
            info["file_status"][filename] = "available"
            
            # Get row count
            try:
                data = read_csv_file(filename)
                info["file_status"][filename] = f"available ({len(data)} entries)"
            except Exception as e:
                info["file_status"][filename] = f"available (error reading: {str(e)})"
        else:
            info["file_status"][filename] = "missing"
    
    return info