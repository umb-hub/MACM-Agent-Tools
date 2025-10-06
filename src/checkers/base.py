"""
Base Checker Interface
Abstract base class for all MACM validation checkers
"""

from abc import ABC, abstractmethod
from typing import List, Dict, Any
from core.models.base import ArchitectureModel
from core.models.validation import ValidationResult


class BaseChecker(ABC):
    """Abstract base class for all validation checkers"""
    
    def __init__(self):
        """Initialize checker"""
        self.errors = []
        self.warnings = []
    
    @abstractmethod
    def validate(self, model: ArchitectureModel) -> ValidationResult:
        """Perform validation on architecture model"""
        pass
    
    def reset(self):
        """Reset checker state"""
        self.errors = []
        self.warnings = []
    
    def add_error(self, message: str):
        """Add error message"""
        self.errors.append(message)
    
    def add_warning(self, message: str):
        """Add warning message"""
        self.warnings.append(message)
    
    def create_result(self, summary: Dict[str, Any] = None) -> ValidationResult:
        """Create validation result from current state"""
        return ValidationResult(
            valid=len(self.errors) == 0,
            errors=self.errors.copy(),
            warnings=self.warnings.copy(),
            summary=summary or {}
        )