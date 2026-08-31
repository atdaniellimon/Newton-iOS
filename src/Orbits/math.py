# src/Orbits/calculator.py
"""
Advanced Calculator Orbit - Safe evaluation of mathematical expressions
Supports more functions and operations than math.py
"""

import ast
import operator
import math
import statistics
import random
from typing import Dict, Any, List, Union

# Allowed operators
ALLOWED_OPERATORS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.Div: operator.truediv,
    ast.FloorDiv: operator.floordiv,
    ast.Mod: operator.mod,
    ast.Pow: operator.pow,
    ast.USub: operator.neg,
    ast.UAdd: operator.pos,
}

# Allowed functions (extended)
ALLOWED_FUNCTIONS = {
    # Math
    'abs': abs,
    'round': round,
    'min': min,
    'max': max,
    'sum': sum,
    'len': len,
    'sqrt': math.sqrt,
    'sin': math.sin,
    'cos': math.cos,
    'tan': math.tan,
    'asin': math.asin,
    'acos': math.acos,
    'atan': math.atan,
    'log': math.log,
    'log10': math.log10,
    'log2': math.log2,
    'exp': math.exp,
    'pi': math.pi,
    'e': math.e,
    'tau': math.tau,
    'factorial': math.factorial,
    'gcd': math.gcd,
    'lcm': math.lcm,
    'degrees': math.degrees,
    'radians': math.radians,
    'sinh': math.sinh,
    'cosh': math.cosh,
    'tanh': math.tanh,
    'erf': math.erf,
    'erfc': math.erfc,
    'gamma': math.gamma,
    'lgamma': math.lgamma,
    # Statistics
    'mean': statistics.mean,
    'median': statistics.median,
    'mode': statistics.mode,
    'stdev': statistics.stdev,
    'variance': statistics.variance,
    # Random (seeded)
    'randint': random.randint,
    'uniform': random.uniform,
    'choice': random.choice,
}

class SafeEvaluator(ast.NodeVisitor):
    def __init__(self, variables: Dict[str, Union[int, float]] = None):
        self.variables = variables or {}
        self.used_names = set()
    
    def visit_Constant(self, node):
        return node.value
    
    def visit_Name(self, node):
        self.used_names.add(node.id)
        if node.id in self.variables:
            return self.variables[node.id]
        elif node.id in ALLOWED_FUNCTIONS:
            return ALLOWED_FUNCTIONS[node.id]
        else:
            raise ValueError(f"Unknown identifier: {node.id}")
    
    def visit_BinOp(self, node):
        left = self.visit(node.left)
        right = self.visit(node.right)
        op = type(node.op)
        if op not in ALLOWED_OPERATORS:
            raise ValueError(f"Operator not allowed: {op.__name__}")
        return ALLOWED_OPERATORS[op](left, right)
    
    def visit_UnaryOp(self, node):
        operand = self.visit(node.operand)
        op = type(node.op)
        if op not in ALLOWED_OPERATORS:
            raise ValueError(f"Operator not allowed: {op.__name__}")
        return ALLOWED_OPERATORS[op](operand)
    
    def visit_Call(self, node):
        # Function call
        if not isinstance(node.func, ast.Name):
            raise ValueError("Only simple function calls allowed")
        
        func_name = node.func.id
        if func_name not in ALLOWED_FUNCTIONS:
            raise ValueError(f"Function not allowed: {func_name}")
        
        func = ALLOWED_FUNCTIONS[func_name]
        args = [self.visit(arg) for arg in node.args]
        
        # Special handling for random functions (need seed)
        if func_name in ['randint', 'uniform', 'choice']:
            # We'll use system randomness
            pass
        
        return func(*args)
    
    def evaluate(self, expression: str) -> Union[int, float]:
        tree = ast.parse(expression, mode='eval')
        result = self.visit(tree.body)
        # Clean up floats
        if isinstance(result, float) and result.is_integer():
            result = int(result)
        return result


class CalculatorOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.max_expression_length = self.config.get('max_expression_length', 500)
    
    async def execute(self, expression: str = None, **kwargs) -> Dict[str, Any]:
        if not expression:
            return {'success': False, 'error': "Missing 'expression'"}
        
        if len(expression) > self.max_expression_length:
            return {'success': False, 'error': f"Expression too long (max {self.max_expression_length})"}
        
        # Basic safety checks
        dangerous = ['__', 'import', 'exec', 'eval', 'open', 'compile', 'globals', 'locals']
        for d in dangerous:
            if d in expression:
                return {'success': False, 'error': f"Contains forbidden: {d}"}
        
        try:
            evaluator = SafeEvaluator()
            result = evaluator.evaluate(expression)
            
            # Show used variables/functions (for debugging)
            used = list(evaluator.used_names)
            
            return {
                'success': True,
                'data': {
                    'expression': expression,
                    'result': result,
                    'type': type(result).__name__,
                    'used_functions': used if used else None
                }
            }
        except Exception as e:
            return {'success': False, 'error': str(e)}
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'calculator',
            'version': '1.0.0',
            'description': 'Advanced mathematical calculator with statistics and random functions',
            'supported_functions': list(ALLOWED_FUNCTIONS.keys()),
            'operators': ['+', '-', '*', '/', '//', '%', '**']
        }


async def execute(expression: str = None, **kwargs):
    orbit = CalculatorOrbit()
    return await orbit.execute(expression=expression, **kwargs)