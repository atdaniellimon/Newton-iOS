# src/Orbits/file_manager.py
"""
File Manager Orbit - Interact with uploaded files (read, list, analyze)
This orbit gives the LLM ability to work with files in the session.
"""

import os
from pathlib import Path
from typing import Dict, Any, List
import json
import csv
import io

# Base uploads directory (relative to this file)
UPLOADS_BASE = Path(__file__).parent / "uploads"

class FileManagerOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.max_read_size = self.config.get('max_read_size', 50000)  # 50KB for reading into context
    
    async def execute(self, action: str = 'list', session_id: str = None, filename: str = None, **kwargs) -> Dict[str, Any]:
        """
        Manage files in the session.
        action: list, read, analyze (detect type and preview)
        """
        if not session_id:
            session_id = kwargs.get('session', 'default')
        
        session_dir = UPLOADS_BASE / session_id
        if not session_dir.exists():
            if action == 'list':
                return {'success': True, 'data': {'files': [], 'session': session_id}}
            else:
                return {'success': False, 'error': f'Session {session_id} not found'}
        
        if action == 'list':
            files = []
            for f in session_dir.iterdir():
                if f.is_file():
                    files.append({
                        'name': f.name,
                        'size': f.stat().st_size,
                        'modified': f.stat().st_mtime
                    })
            return {
                'success': True,
                'data': {
                    'session': session_id,
                    'files': files,
                    'count': len(files)
                }
            }
        
        elif action == 'read':
            if not filename:
                return {'success': False, 'error': "Missing 'filename'"}
            
            file_path = session_dir / filename
            if not file_path.exists():
                return {'success': False, 'error': f"File '{filename}' not found"}
            
            # Check size
            if file_path.stat().st_size > self.max_read_size:
                return {
                    'success': False,
                    'error': f"File too large ({file_path.stat().st_size} > {self.max_read_size} bytes)"
                }
            
            # Try to read as text
            try:
                content = file_path.read_text(encoding='utf-8')
                return {
                    'success': True,
                    'data': {
                        'filename': filename,
                        'content': content,
                        'size': file_path.stat().st_size
                    }
                }
            except UnicodeDecodeError:
                # Binary file - return preview
                return {
                    'success': False,
                    'error': 'File is binary and cannot be read as text',
                    'data': {'filename': filename, 'binary': True}
                }
        
        elif action == 'analyze':
            if not filename:
                return {'success': False, 'error': "Missing 'filename'"}
            
            file_path = session_dir / filename
            if not file_path.exists():
                return {'success': False, 'error': f"File '{filename}' not found"}
            
            ext = file_path.suffix.lower()
            info = {
                'filename': filename,
                'size': file_path.stat().st_size,
                'extension': ext,
                'type': 'unknown'
            }
            
            # Detect type
            if ext in ['.txt', '.md', '.json', '.py', '.js', '.html', '.css', '.csv']:
                info['type'] = 'text'
                # Try to read first few lines
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        preview = f.read(500)
                    info['preview'] = preview
                except:
                    pass
            elif ext in ['.png', '.jpg', '.jpeg', '.gif', '.bmp']:
                info['type'] = 'image'
            elif ext in ['.pdf']:
                info['type'] = 'pdf'
            else:
                info['type'] = 'other'
            
            return {
                'success': True,
                'data': info
            }
        
        else:
            return {'success': False, 'error': f"Unknown action: {action}"}
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'file_manager',
            'version': '1.0.0',
            'description': 'List, read, and analyze uploaded files in the session',
            'actions': ['list', 'read', 'analyze'],
            'max_read_size': self.max_read_size
        }


async def execute(action: str = 'list', session_id: str = None, filename: str = None, **kwargs):
    orbit = FileManagerOrbit()
    return await orbit.execute(action=action, session_id=session_id, filename=filename, **kwargs)