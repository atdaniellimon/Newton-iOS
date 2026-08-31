# backend/orbit_manager.py
"""
Gestor de Órbitas - Integra las órbitas con el backend de Newton
"""

import importlib
import json
from pathlib import Path
from typing import Dict, Any, Optional

class OrbitManager:
    """Administra todas las órbitas disponibles"""
    
    def __init__(self, config_path: str = 'orbits_config.json'):
        self.orbits: Dict[str, BaseOrbit] = {}
        self.config = self._load_config(config_path)
        self._initialize_orbits()
    
    def _load_config(self, path: str) -> dict:
        """Carga configuración de órbitas"""
        default_config = {
            'orbits': {
                'filesystem': {
                    'enabled': True,
                    'class': 'filesystem_orbit.FileSystemOrbit',
                    'config': {
                        'mode': 'read-only',
                        'allowed_directories': ['./workspace'],
                        'max_file_size': 10485760
                    }
                },
                'web_search': {
                    'enabled': False,
                    'class': 'web_orbit.WebSearchOrbit',
                    'config': {
                        'max_results': 5,
                        'timeout': 10,
                        'enable_scraping': False
                    }
                }
            }
        }
        
        if Path(path).exists():
            with open(path, 'r') as f:
                return json.load(f)
        else:
            with open(path, 'w') as f:
                json.dump(default_config, f, indent=2)
            return default_config
    
    def _initialize_orbits(self):
        """Inicializa las órbitas habilitadas"""
        for orbit_name, orbit_data in self.config['orbits'].items():
            if orbit_data.get('enabled', False):
                try:
                    # Importar dinámicamente la clase
                    module_path, class_name = orbit_data['class'].rsplit('.', 1)
                    module = importlib.import_module(f'orbits.{module_path}')
                    orbit_class = getattr(module, class_name)
                    
                    # Instanciar órbita
                    orbit = orbit_class(orbit_data.get('config', {}))
                    self.orbits[orbit_name] = orbit
                    
                    print(f"✅ Orbit '{orbit_name}' initialized")
                except Exception as e:
                    print(f"❌ Failed to initialize orbit '{orbit_name}': {e}")
    
    async def execute_orbit(self, orbit_name: str, **kwargs) -> Dict[str, Any]:
        """Ejecuta una órbita específica"""
        if orbit_name not in self.orbits:
            return {
                'success': False,
                'error': f"Orbit '{orbit_name}' not found or disabled",
                'available_orbits': list(self.orbits.keys())
            }
        
        orbit = self.orbits[orbit_name]
        
        # Validación previa
        if not await orbit.validate(**kwargs):
            return {
                'success': False,
                'error': f"Validation failed for orbit '{orbit_name}'"
            }
        
        # Ejecutar
        response = await orbit.execute(**kwargs)
        return response.to_dict()
    
    def get_status(self) -> Dict[str, Any]:
        """Estado de todas las órbitas"""
        return {
            'orbits': {
                name: orbit.get_capabilities() 
                for name, orbit in self.orbits.items()
            },
            'total': len(self.orbits),
            'config_version': self.config.get('version', '1.0')
        }