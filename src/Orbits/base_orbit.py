# src/Orbits/base_orbit.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any, Dict, Optional

@dataclass
class OrbitResponse:
    """Standard orbit response"""
    success: bool
    data: Any = None
    error: Optional[str] = None
    metadata: Optional[Dict] = None
    
    def to_dict(self):
        return {
            'success': self.success,
            'data': self.data,
            'error': self.error,
            'metadata': self.metadata
        }


class BaseOrbit(ABC):
    """Base class for all orbits"""
    
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.name = self.__class__.__name__
    
    @abstractmethod
    async def execute(self, **kwargs) -> OrbitResponse:
        """Execute the orbit - MUST be implemented by subclasses"""
        pass
    
    def get_capabilities(self) -> dict:
        """Return orbit capabilities (optional override)"""
        return {
            'name': self.name,
            'class': self.__class__.__name__
        }