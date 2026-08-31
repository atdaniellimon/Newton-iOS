"""
Newton Backend Server with Orbits Support
Proxy for Zenmux API + Orbit execution + File management + Code execution
WITH TOOL CALLING SUPPORT
"""

import json
import sys
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import urllib.request
import ssl
import asyncio
from pathlib import Path
import importlib.util
from typing import Dict, Any, List
import os
import tempfile
import shutil
import mimetypes
import subprocess
import signal
import threading
import time
from dotenv import load_dotenv
import email.parser
import email.policy
from io import BytesIO

# Import the OpenAI library
from openai import OpenAI

# Cargar variables de entorno desde .env
load_dotenv()

BACKEND_PORT = 5000
UPLOADS_DIR = Path(__file__).parent.parent / "src" / "Orbits" / "uploads"

# ========== Ensure uploads directory exists ==========
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

# ========== Orbit Manager ==========
class OrbitManager:
    def __init__(self, orbits_path: str = None):
        if not orbits_path:
            self.orbits_path = Path(__file__).parent.parent / "src" / "Orbits"
        else:
            self.orbits_path = Path(orbits_path)
        
        sys.path.insert(0, str(self.orbits_path))
        self.orbits: Dict[str, Any] = {}
        self._load_orbits()
    
    def _load_orbits(self):
        if not self.orbits_path.exists():
            print(f"⚠️ Orbits directory not found: {self.orbits_path}")
            return
        
        for orbit_file in self.orbits_path.glob("*.py"):
            if orbit_file.name.startswith("__"):
                continue
            if orbit_file.name in ["base_orbit.py", "orbit_manager.py"]:
                continue
            
            orbit_name = orbit_file.stem
            try:
                spec = importlib.util.spec_from_file_location(f"orbits_{orbit_name}", orbit_file)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                orbit_instance = None
                class_name = f"{orbit_name.capitalize()}Orbit"
                if hasattr(module, class_name):
                    orbit_class = getattr(module, class_name)
                    config = self._load_orbit_config(orbit_name)
                    orbit_instance = orbit_class(config)
                    print(f"✅ Loaded orbit: {orbit_name} (class)")
                elif hasattr(module, 'Orbit'):
                    orbit_class = getattr(module, 'Orbit')
                    config = self._load_orbit_config(orbit_name)
                    orbit_instance = orbit_class(config)
                    print(f"✅ Loaded orbit: {orbit_name} (Orbit class)")
                elif hasattr(module, 'execute') and callable(module.execute):
                    orbit_instance = module
                    print(f"✅ Loaded orbit: {orbit_name} (function)")
                else:
                    for attr_name in dir(module):
                        if attr_name.endswith('Orbit'):
                            orbit_class = getattr(module, attr_name)
                            if hasattr(orbit_class, 'execute'):
                                config = self._load_orbit_config(orbit_name)
                                orbit_instance = orbit_class(config)
                                print(f"✅ Loaded orbit: {orbit_name} (from {attr_name})")
                                break
                
                if orbit_instance:
                    self.orbits[orbit_name] = orbit_instance
                else:
                    print(f"⚠️ No compatible orbit found in {orbit_file.name}")
            except Exception as e:
                print(f"❌ Failed to load orbit {orbit_name}: {e}")
    
    def _load_orbit_config(self, orbit_name: str) -> dict:
        config_path = self.orbits_path / f"{orbit_name}.config.json"
        if config_path.exists():
            with open(config_path, 'r') as f:
                return json.load(f)
        return {}
    
    async def execute(self, orbit_name: str, params: dict) -> dict:
        if orbit_name not in self.orbits:
            return {
                'success': False,
                'error': f"Orbit '{orbit_name}' not found",
                'available': list(self.orbits.keys())
            }
        
        orbit = self.orbits[orbit_name]
        try:
            if hasattr(orbit, 'execute'):
                if asyncio.iscoroutinefunction(orbit.execute):
                    result = await orbit.execute(**params)
                else:
                    result = orbit.execute(**params)
            elif hasattr(orbit, 'run'):
                if asyncio.iscoroutinefunction(orbit.run):
                    result = await orbit.run(**params)
                else:
                    result = orbit.run(**params)
            else:
                if asyncio.iscoroutinefunction(orbit.execute):
                    result = await orbit.execute(**params)
                else:
                    result = orbit.execute(**params)
            
            # Asegurar que el resultado tenga una estructura consistente
            if isinstance(result, dict):
                if 'success' not in result:
                    result = {
                        'success': True,
                        'data': result
                    }
            else:
                result = {
                    'success': True,
                    'data': result
                }
            
            return {
                'success': True,
                'data': result.get('data', result),
                'orbit': orbit_name
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'orbit': orbit_name
            }
    
    def get_status(self) -> dict:
        status = {}
        for name, orbit in self.orbits.items():
            if hasattr(orbit, 'get_capabilities'):
                status[name] = orbit.get_capabilities()
            else:
                status[name] = {'type': 'function', 'available': True}
        return status
    
    def get_tools_definitions(self) -> List[Dict]:
        """Genera definiciones de herramientas para OpenAI"""
        tools = []
        
        for name, orbit in self.orbits.items():
            capabilities = {}
            if hasattr(orbit, 'get_capabilities'):
                capabilities = orbit.get_capabilities()
            
            # Construir parámetros de la herramienta
            parameters = {
                "type": "object",
                "properties": {},
                "required": []
            }
            
            # Extraer parámetros de las capacidades
            if 'parameters' in capabilities and isinstance(capabilities['parameters'], dict):
                for param_name, param_info in capabilities['parameters'].items():
                    if isinstance(param_info, dict):
                        param_type = param_info.get('type', 'string')
                        param_desc = param_info.get('description', '')
                        is_required = param_info.get('required', False)
                    else:
                        param_type = 'string'
                        param_desc = str(param_info)
                        is_required = False
                    
                    parameters['properties'][param_name] = {
                        'type': param_type,
                        'description': param_desc
                    }
                    
                    if is_required:
                        parameters['required'].append(param_name)
            else:
                # Parámetros genéricos
                parameters['properties'] = {
                    'query': {
                        'type': 'string',
                        'description': 'The main input or query for the orbit'
                    }
                }
                parameters['required'] = ['query']
            
            # Si no hay parámetros definidos, hacer que todos sean opcionales
            if not parameters['properties']:
                parameters['properties'] = {
                    'input': {
                        'type': 'string',
                        'description': 'Input for the orbit'
                    }
                }
                parameters['required'] = []
            
            tool_def = {
                "type": "function",
                "function": {
                    "name": name,
                    "description": capabilities.get('description', f'Execute {name} orbit'),
                    "parameters": parameters
                }
            }
            
            tools.append(tool_def)
        
        return tools

orbit_manager = None

# ========== Code Execution Functions ==========
def execute_c(code: str, timeout: int = 10) -> dict:
    """Compila y ejecuta código C en un subproceso seguro"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.c', delete=False) as f:
        f.write(code)
        c_path = f.name
    
    exe_path = c_path.replace('.c', '.out')
    
    try:
        compile_proc = subprocess.Popen(
            ['gcc', c_path, '-o', exe_path, '-Wall', '-O2'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        _, compile_err = compile_proc.communicate(timeout=10)
        
        if compile_proc.returncode != 0:
            return {
                'success': False,
                'error': f'Compilation failed:\n{compile_err}'
            }
        
        proc = subprocess.Popen(
            [exe_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        def kill_proc():
            try:
                proc.terminate()
                time.sleep(0.5)
                proc.kill()
            except:
                pass
        
        timer = threading.Timer(timeout, kill_proc)
        timer.start()
        stdout, stderr = proc.communicate()
        timer.cancel()
        
        try:
            os.unlink(c_path)
            os.unlink(exe_path)
        except:
            pass
        
        if proc.returncode == 0:
            return {'success': True, 'output': stdout.strip() or '(no output)'}
        else:
            return {'success': False, 'error': stderr.strip() or 'Execution failed'}
            
    except subprocess.TimeoutExpired:
        try:
            os.unlink(c_path)
            os.unlink(exe_path)
        except:
            pass
        return {'success': False, 'error': 'Compilation timed out'}
    except FileNotFoundError:
        return {'success': False, 'error': 'GCC not installed. Please install GCC to compile C code.'}
    except Exception as e:
        try:
            os.unlink(c_path)
            os.unlink(exe_path)
        except:
            pass
        return {'success': False, 'error': str(e)}

def execute_rust(code: str, timeout: int = 15) -> dict:
    """Compila y ejecuta código Rust en un subproceso seguro"""
    rustc_path = shutil.which('rustc')
    if not rustc_path:
        common_paths = [
            '/usr/local/bin/rustc',
            '/opt/homebrew/bin/rustc',
            f'{os.path.expanduser("~")}/.cargo/bin/rustc',
            '/usr/bin/rustc'
        ]
        for path in common_paths:
            if os.path.exists(path):
                rustc_path = path
                break
    
    if not rustc_path:
        return {'success': False, 'error': 'Rust not installed. Please install Rust (rustc) to compile Rust code.'}
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.rs', delete=False) as f:
        f.write(code)
        rs_path = f.name
    
    exe_path = rs_path.replace('.rs', '.out')
    
    try:
        compile_proc = subprocess.Popen(
            [rustc_path, rs_path, '-o', exe_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env={**os.environ, 'PATH': os.environ.get('PATH', '') + ':/usr/local/bin:/opt/homebrew/bin:~/.cargo/bin'}
        )
        _, compile_err = compile_proc.communicate(timeout=15)
        
        if compile_proc.returncode != 0:
            try:
                os.unlink(rs_path)
            except:
                pass
            return {
                'success': False,
                'error': f'Compilation failed:\n{compile_err}'
            }
        
        proc = subprocess.Popen(
            [exe_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        def kill_proc():
            try:
                proc.terminate()
                time.sleep(0.5)
                proc.kill()
            except:
                pass
        
        timer = threading.Timer(timeout, kill_proc)
        timer.start()
        stdout, stderr = proc.communicate()
        timer.cancel()
        
        try:
            os.unlink(rs_path)
            os.unlink(exe_path)
        except:
            pass
        
        if proc.returncode == 0:
            return {'success': True, 'output': stdout.strip() or '(no output)'}
        else:
            return {'success': False, 'error': stderr.strip() or 'Execution failed'}
            
    except subprocess.TimeoutExpired:
        try:
            os.unlink(rs_path)
            os.unlink(exe_path)
        except:
            pass
        return {'success': False, 'error': 'Compilation timed out'}
    except Exception as e:
        try:
            os.unlink(rs_path)
            os.unlink(exe_path)
        except:
            pass
        return {'success': False, 'error': str(e)}

def execute_python(code: str, timeout: int = 10) -> dict:
    """Ejecuta código Python en un subproceso seguro con timeout"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(code)
        tmp_path = f.name
    
    try:
        proc = subprocess.Popen(
            [sys.executable, tmp_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=os.path.dirname(tmp_path)
        )
        
        def kill_proc():
            try:
                proc.terminate()
                time.sleep(0.5)
                proc.kill()
            except:
                pass
        
        timer = threading.Timer(timeout, kill_proc)
        timer.start()
        stdout, stderr = proc.communicate()
        timer.cancel()
        
        if proc.returncode == 0:
            return {'success': True, 'output': stdout.strip() or '(no output)'}
        else:
            return {'success': False, 'error': stderr.strip() or 'Execution failed with no error message'}
    except Exception as e:
        return {'success': False, 'error': str(e)}
    finally:
        try:
            os.unlink(tmp_path)
        except:
            pass

def execute_javascript(code: str, timeout: int = 10) -> dict:
    """Ejecuta JavaScript usando Node.js (requiere Node instalado)"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.js', delete=False) as f:
        f.write(code)
        tmp_path = f.name
    
    try:
        proc = subprocess.Popen(
            ['node', tmp_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        def kill_proc():
            try:
                proc.terminate()
                time.sleep(0.5)
                proc.kill()
            except:
                pass
        
        timer = threading.Timer(timeout, kill_proc)
        timer.start()
        stdout, stderr = proc.communicate()
        timer.cancel()
        
        if proc.returncode == 0:
            return {'success': True, 'output': stdout.strip() or '(no output)'}
        else:
            return {'success': False, 'error': stderr.strip() or 'Execution failed'}
    except FileNotFoundError:
        return {'success': False, 'error': 'Node.js not installed. Please install Node to run JavaScript.'}
    except Exception as e:
        return {'success': False, 'error': str(e)}
    finally:
        try:
            os.unlink(tmp_path)
        except:
            pass

# ========== Proxy Handler ==========
class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    
    def _set_cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, DELETE')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Session-Id')
        self.send_header('Access-Control-Max-Age', '86400')
    
    def _send_json(self, status_code, data):
        body = json.dumps(data, default=str).encode('utf-8')
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self._set_cors_headers()
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    
    def _send_file(self, file_path: Path):
        if not file_path.exists():
            self._send_json(404, {'error': 'File not found'})
            return
        mime_type, _ = mimetypes.guess_type(file_path.name)
        if not mime_type:
            mime_type = 'application/octet-stream'
        self.send_response(200)
        self.send_header('Content-Type', mime_type)
        self.send_header('Content-Disposition', f'attachment; filename="{file_path.name}"')
        self._set_cors_headers()
        self.send_header('Content-Length', str(file_path.stat().st_size))
        self.end_headers()
        with open(file_path, 'rb') as f:
            self.wfile.write(f.read())
    
    def do_OPTIONS(self):
        self.send_response(204)
        self._set_cors_headers()
        self.end_headers()
    
    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == '/api/chat':
            self._handle_chat()
        elif parsed.path == '/api/orbit':
            self._handle_orbit()
        elif parsed.path == '/api/upload':
            self._handle_upload()
        elif parsed.path == '/api/delete':
            self._handle_delete()
        elif parsed.path == '/api/execute':
            self._handle_execute()
        else:
            self._send_json(404, {'error': 'Not found'})
    
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/api/health':
            self._send_json(200, {'status': 'ok', 'message': 'Newton backend running'})
        elif parsed.path == '/api/orbits':
            self._handle_list_orbits()
        elif parsed.path == '/api/files':
            self._handle_list_files()
        elif parsed.path == '/api/download':
            self._handle_download()
        else:
            self._send_json(404, {'error': 'Not found'})
    
    def do_DELETE(self):
        parsed = urlparse(self.path)
        if parsed.path == '/api/delete':
            self._handle_delete()
        else:
            self._send_json(404, {'error': 'Not found'})
    
    # ========== File Management Endpoints ==========
    def _get_session_dir(self, session_id: str) -> Path:
        session_dir = UPLOADS_DIR / session_id
        session_dir.mkdir(parents=True, exist_ok=True)
        return session_dir
    
    def _handle_upload(self):
        """Maneja upload de archivos sin usar cgi"""
        content_type = self.headers.get('Content-Type', '')
        if not content_type.startswith('multipart/form-data'):
            self._send_json(400, {'error': 'Expected multipart/form-data'})
            return
        
        session_id = self.headers.get('X-Session-Id', 'default')
        
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            
            boundary = content_type.split('boundary=')[1]
            if boundary.startswith('"') and boundary.endswith('"'):
                boundary = boundary[1:-1]
            
            parts = body.split(f'--{boundary}'.encode())
            
            filename = None
            file_data = None
            
            for part in parts:
                if not part or part == b'--\r\n' or part == b'--':
                    continue
                
                if b'Content-Disposition:' in part:
                    lines = part.split(b'\r\n')
                    for line in lines:
                        if b'filename=' in line:
                            filename_part = line.decode('utf-8', errors='ignore')
                            if 'filename=' in filename_part:
                                start = filename_part.find('filename=') + 9
                                end = filename_part.find('"', start + 1)
                                if end == -1:
                                    end = len(filename_part)
                                filename = filename_part[start:end].strip('"')
                        
                        if b'Content-Type:' in line:
                            content_start = part.find(b'\r\n\r\n') + 4
                            if content_start > 4:
                                file_data = part[content_start:].rstrip(b'\r\n')
            
            if not filename or not file_data:
                self._send_json(400, {'error': 'No file found in upload'})
                return
            
            filename = ''.join(c for c in filename if c.isalnum() or c in '._- ')
            session_dir = self._get_session_dir(session_id)
            file_path = session_dir / filename
            
            with open(file_path, 'wb') as f:
                f.write(file_data)
            
            file_size = file_path.stat().st_size
            self._send_json(200, {
                'success': True,
                'file': {
                    'name': filename,
                    'path': str(file_path),
                    'size': file_size,
                    'session': session_id
                }
            })
            
        except Exception as e:
            self._send_json(500, {'error': f'Upload failed: {str(e)}'})
    
    def _handle_list_files(self):
        query = parse_qs(urlparse(self.path).query)
        session_id = query.get('session', ['default'])[0]
        session_dir = self._get_session_dir(session_id)
        files = []
        for file_path in session_dir.iterdir():
            if file_path.is_file():
                files.append({
                    'name': file_path.name,
                    'size': file_path.stat().st_size,
                    'modified': file_path.stat().st_mtime,
                    'path': str(file_path)
                })
        self._send_json(200, {
            'success': True,
            'session': session_id,
            'files': files,
            'count': len(files)
        })
    
    def _handle_download(self):
        query = parse_qs(urlparse(self.path).query)
        filename = query.get('file', [None])[0]
        session_id = query.get('session', ['default'])[0]
        if not filename:
            self._send_json(400, {'error': 'Missing file parameter'})
            return
        filename = os.path.basename(filename)
        session_dir = self._get_session_dir(session_id)
        file_path = session_dir / filename
        if not file_path.exists():
            self._send_json(404, {'error': 'File not found'})
            return
        self._send_file(file_path)
    
    def _handle_delete(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        try:
            data = json.loads(body.decode('utf-8'))
        except:
            self._send_json(400, {'error': 'Invalid JSON'})
            return
        filename = data.get('filename')
        session_id = data.get('sessionId', 'default')
        if not filename:
            self._send_json(400, {'error': 'Missing filename'})
            return
        filename = os.path.basename(filename)
        session_dir = self._get_session_dir(session_id)
        file_path = session_dir / filename
        if not file_path.exists():
            self._send_json(404, {'error': 'File not found'})
            return
        try:
            file_path.unlink()
            self._send_json(200, {'success': True, 'message': f'Deleted {filename}'})
        except Exception as e:
            self._send_json(500, {'error': f'Delete failed: {str(e)}'})
    
    # ========== Orbit Endpoints ==========
    def _handle_list_orbits(self):
        if orbit_manager is None:
            self._send_json(503, {'error': 'Orbit manager not initialized'})
            return
        status = orbit_manager.get_status()
        self._send_json(200, {
            'orbits': status,
            'total': len(status)
        })
    
    def _handle_orbit(self):
        global orbit_manager
        if orbit_manager is None:
            self._send_json(503, {'error': 'Orbit manager not initialized'})
            return
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, {'error': 'Invalid JSON body'})
            return
        orbit_name = data.get('orbit')
        params = data.get('params', {})
        if not orbit_name:
            self._send_json(400, {'error': 'Missing "orbit" field'})
            return
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(
                orbit_manager.execute(orbit_name, params)
            )
            self._send_json(200, result)
        except Exception as e:
            self._send_json(500, {'error': str(e)})
        finally:
            loop.close()
    
    # ========== Code Execution Endpoint ==========
    def _handle_execute(self):
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, {'error': 'Invalid JSON body'})
            return
        
        code = data.get('code', '')
        language = data.get('language', 'python')
        timeout = data.get('timeout', 10)
        
        if not code:
            self._send_json(400, {'error': 'Missing "code" field'})
            return
        
        if len(code) > 50000:
            self._send_json(400, {'error': 'Code too long (max 50000 characters)'})
            return
        
        if language == 'python':
            result = execute_python(code, timeout)
        elif language in ['javascript', 'js']:
            result = execute_javascript(code, timeout)
        elif language == 'c':
            result = execute_c(code, timeout)
        elif language == 'rust':
            result = execute_rust(code, timeout)
        else:
            self._send_json(400, {'error': f'Language "{language}" is not yet supported'})
            return
        
        self._send_json(200, result)

    # ========== Chat Proxy with Tool Calling ==========
    def _handle_chat(self):
        global orbit_manager
        
        zenmux_api_key = os.getenv('ZENMUX_API_KEY')
        if not zenmux_api_key:
            self._send_json(500, {'error': 'Zenmux API key not configured in .env'})
            return
        
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, {'error': 'Invalid JSON body'})
            return
        
        model = data.get('model', 'z-ai/glm-4.7-flash-free')
        messages = data.get('messages', [])
        temperature = data.get('temperature', 0.7)
        max_tokens = data.get('maxTokens', 2048)
        
        # Obtener herramientas disponibles
        tools = orbit_manager.get_tools_definitions() if orbit_manager else []
        
        try:
            # Configurar cliente OpenAI
            client = OpenAI(
                api_key=zenmux_api_key,
                base_url="https://zenmux.ai/api/v1",
                default_headers={
                    'HTTP-Referer': os.getenv('ZENMUX_REFERER', 'http://localhost:3000'),
                    'X-Title': os.getenv('ZENMUX_TITLE', 'Newton'),
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    'Accept': 'application/json, text/plain, */*',
                    'Accept-Language': 'en-US,en;q=0.9'
                }
            )
            
            # Primera llamada con herramientas
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                tools=tools if tools else None,
                tool_choice='auto' if tools else None
            )
            
            choice = response.choices[0]
            
            # Verificar si hay tool calls
            if choice.finish_reason == 'tool_calls' and choice.message.tool_calls:
                # Añadir el mensaje de la IA a la conversación
                messages.append(choice.message.model_dump())
                
                # Ejecutar todas las herramientas en paralelo
                async def execute_tools():
                    tasks = []
                    for tool_call in choice.message.tool_calls:
                        function_name = tool_call.function.name
                        try:
                            function_args = json.loads(tool_call.function.arguments) if tool_call.function.arguments else {}
                        except:
                            function_args = {}
                        
                        tasks.append(orbit_manager.execute(function_name, function_args))
                    
                    results = await asyncio.gather(*tasks, return_exceptions=True)
                    return results
                
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                try:
                    tool_results = loop.run_until_complete(execute_tools())
                finally:
                    loop.close()
                
                # Crear mensajes de herramienta
                for i, tool_call in enumerate(choice.message.tool_calls):
                    result = tool_results[i] if i < len(tool_results) else {'error': 'Tool execution failed'}
                    
                    if isinstance(result, dict):
                        if result.get('success', False):
                            content_data = result.get('data', result)
                        else:
                            content_data = {'error': result.get('error', 'Unknown error')}
                    else:
                        content_data = {'result': str(result)}
                    
                    messages.append({
                        'role': 'tool',
                        'tool_call_id': tool_call.id,
                        'content': json.dumps(content_data, default=str)
                    })
                
                # Segunda llamada con los resultados de las herramientas (sin tools)
                final_response = client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=temperature,
                    max_tokens=max_tokens
                )
                
                self._send_json(200, final_response.model_dump())
                return
            
            # Si no hay tool calls, devolver la respuesta normal
            self._send_json(200, response.model_dump())
            
        except Exception as e:
            self._send_json(500, {
                'error': 'Internal Error or API Connection Error',
                'detail': str(e)
            })
    
    def log_message(self, format, *args):
        if getattr(self.server, 'verbose', False):
            print(f"[{self.address_string()}] {format % args}")

# ========== Server Runner ==========
def run_server(port=BACKEND_PORT, verbose=False):
    global orbit_manager
    print("🔭 Initializing Newton Orbits...")
    orbit_manager = OrbitManager()
    status = orbit_manager.get_status()
    if status:
        print(f"   Loaded {len(status)} orbits: {', '.join(status.keys())}")
    else:
        print("   No orbits found. Add .py files to /src/Orbits/")
    
    server = HTTPServer(('0.0.0.0', port), ProxyHandler)
    server.verbose = verbose
    
    print(f'\n⚡ Newton Backend running on http://localhost:{port}')
    print(f'   Endpoints:')
    print(f'   POST /api/chat     - Proxy to Zenmux (with Tool Calling)')
    print(f'   POST /api/orbit    - Execute an orbit')
    print(f'   GET  /api/orbits   - List available orbits')
    print(f'   GET  /api/health   - Health check')
    print(f'   POST /api/upload   - Upload file')
    print(f'   GET  /api/files    - List files')
    print(f'   GET  /api/download - Download file')
    print(f'   POST /api/delete   - Delete file')
    print(f'   POST /api/execute  - Execute code (Python, JavaScript, C, Rust)')
    print(f'')
    print(f'   Press Ctrl+C to stop.\n')

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n👋 Shutting down...')
        server.server_close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Newton Backend Server')
    parser.add_argument('--port', type=int, default=BACKEND_PORT,
                        help='Port to run the server on')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Enable verbose logging')
    args = parser.parse_args()
    run_server(port=args.port, verbose=args.verbose)