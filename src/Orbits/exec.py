# src/Orbits/exec.py
"""
Exec Orbit - Sandboxed Python code execution
"""

import ast
import sys
import io
import signal
from typing import Dict, Any

# Configuración
MAX_EXECUTION_TIME = 5
MAX_OUTPUT_SIZE = 10000

# Funciones permitidas
ALLOWED_BUILTINS = {
    'abs', 'all', 'any', 'bool', 'dict', 'enumerate',
    'filter', 'float', 'int', 'len', 'list', 'map',
    'max', 'min', 'range', 'round', 'set', 'sorted',
    'str', 'sum', 'tuple', 'zip', 'print', 'type'
}

ALLOWED_IMPORTS = {
    'math', 'random', 'statistics', 'itertools',
    'functools', 'collections', 'string'
}


class SafeExecutor:
    """Ejecuta código Python en sandbox"""
    
    def __init__(self):
        self.output = io.StringIO()
    
    def _is_safe_node(self, node: ast.AST) -> bool:
        """Verifica que el AST sea seguro"""
        
        forbidden_nodes = (
            ast.Import, ast.ImportFrom,
            ast.Exec, ast.Eval,
            ast.Global, ast.Nonlocal,
            ast.With, ast.Try,
            ast.ClassDef, ast.Lambda, ast.While
        )
        
        if isinstance(node, forbidden_nodes):
            return False
        
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                if node.func.id in ['open', 'exec', 'eval', 'compile', '__import__']:
                    return False
                if node.func.id not in ALLOWED_BUILTINS:
                    return False
        
        if isinstance(node, ast.Attribute):
            if node.attr in ['__import__', '__builtins__', '__subclasses__']:
                return False
        
        for child in ast.iter_child_nodes(node):
            if not self._is_safe_node(child):
                return False
        
        return True
    
    def execute(self, code: str) -> Dict[str, Any]:
        """Ejecuta código de forma segura"""
        
        if not code or len(code) > 5000:
            return {'success': False, 'error': 'Code too long'}
        
        try:
            tree = ast.parse(code)
        except SyntaxError as e:
            return {'success': False, 'error': f'Syntax error: {e}'}
        
        if not self._is_safe_node(tree):
            return {'success': False, 'error': 'Code contains forbidden operations'}
        
        # Entorno seguro
        safe_globals = {
            '__builtins__': {name: __builtins__[name] for name in ALLOWED_BUILTINS if name in __builtins__},
            '__name__': '__sandbox__',
        }
        
        for module_name in ALLOWED_IMPORTS:
            try:
                safe_globals[module_name] = __import__(module_name)
            except ImportError:
                pass
        
        output_buffer = io.StringIO()
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdout = output_buffer
        sys.stderr = output_buffer
        
        def timeout_handler(signum, frame):
            raise TimeoutError(f"Execution exceeded {MAX_EXECUTION_TIME}s")
        
        try:
            if hasattr(signal, 'SIGALRM'):
                signal.signal(signal.SIGALRM, timeout_handler)
                signal.alarm(MAX_EXECUTION_TIME)
            
            exec(compile(tree, '<sandbox>', 'exec'), safe_globals)
            
            if hasattr(signal, 'SIGALRM'):
                signal.alarm(0)
            
            output = output_buffer.getvalue()
            if len(output) > MAX_OUTPUT_SIZE:
                output = output[:MAX_OUTPUT_SIZE] + "\n... (truncated)"
            
            return {
                'success': True,
                'data': {
                    'output': output if output else '(no output)',
                    'output_size': len(output)
                }
            }
            
        except TimeoutError as e:
            return {'success': False, 'error': str(e)}
        except MemoryError:
            return {'success': False, 'error': 'Memory limit exceeded'}
        except Exception as e:
            return {'success': False, 'error': f'Runtime error: {str(e)}'}
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr
            signal.alarm(0)


class ExecOrbit:
    """Sandboxed code execution"""
    
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.executor = SafeExecutor()
    
    async def execute(self, code: str = None, language: str = 'python', **kwargs) -> Dict[str, Any]:
        if not code:
            return {'success': False, 'error': "Missing 'code'"}
        
        if language != 'python':
            return {'success': False, 'error': f"Language '{language}' not supported"}
        
        return self.executor.execute(code)
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'exec',
            'description': 'Sandboxed Python execution',
            'limits': {
                'max_time': f'{MAX_EXECUTION_TIME}s',
                'max_output': f'{MAX_OUTPUT_SIZE} chars',
                'network': False,
                'filesystem': False
            }
        }


async def execute(code: str = None, **kwargs):
    orbit = ExecOrbit()
    return await orbit.execute(code=code, **kwargs)