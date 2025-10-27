"""
Checkers Package
Validation checkers for MACM architecture models
"""

from .base import BaseChecker
from .database import MacmDatabaseChecker
from .database_v2 import MacmDatabaseCheckerV2

# Import other checkers if they exist
try:
    from .syntax import SyntaxChecker
except ImportError:
    SyntaxChecker = None

try:
    from .semantic import SemanticChecker  
except ImportError:
    SemanticChecker = None

# Build __all__ list dynamically
__all__ = ['BaseChecker', 'MacmDatabaseChecker', 'MacmDatabaseCheckerV2']
if SyntaxChecker:
    __all__.append('SyntaxChecker')
if SemanticChecker:
    __all__.append('SemanticChecker')