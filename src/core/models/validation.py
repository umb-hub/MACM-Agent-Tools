"""
Validation Models
Models for validation results and checking operations
"""

from pydantic import BaseModel
from typing import List, Dict, Any


class ValidationResult(BaseModel):
    """Result of validation checks (syntax or semantic)"""
    valid: bool
    errors: List[str] = []
    warnings: List[str] = []
    summary: Dict[str, Any] = {}