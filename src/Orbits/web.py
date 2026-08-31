# src/Orbits/web.py - Versión fetch directo

import aiohttp
import ssl
import re
from urllib.parse import quote_plus
from bs4 import BeautifulSoup
from typing import Dict, Any, List, Optional

class WebOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.max_results = self.config.get('max_results', 5)
        self.timeout = self.config.get('timeout', 15)
        self.user_agent = self.config.get('user_agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
        
        # Configurar SSL para desarrollo
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE

    def _clean_ddg_url(self, url: str) -> str:
        """Convierte URL de DuckDuckGo a URL directa"""
        import urllib.parse
        import html
        
        if 'duckduckgo.com/l/' in url or 'uddg=' in url:
            try:
                # Extraer el parámetro 'uddg' que contiene la URL real
                parsed = urllib.parse.urlparse(url)
                params = urllib.parse.parse_qs(parsed.query)
                
                if 'uddg' in params:
                    real_url = params['uddg'][0]
                    real_url = html.unescape(real_url)
                    return real_url
            except:
                pass
        
        return url
    
    async def execute(self, query: str = None, action: str = 'search', url: str = None, **kwargs) -> Dict[str, Any]:
        """Execute web search or fetch"""
        
        if action == 'search':
            if not query:
                return {'success': False, 'error': "Missing 'query' parameter"}
            
            # Hacemos fetch a DuckDuckGo Lite igual que a cualquier página
            search_url = f"https://lite.duckduckgo.com/lite/?q={quote_plus(query)}"
            
            # FETCH DIRECTO - igual que con atdaniellimon.github.io
            return await self._fetch_and_parse_search(search_url, query)
        
        elif action == 'fetch':
            if not url:
                return {'success': False, 'error': "Missing 'url' parameter"}
            
            if not url.startswith(('http://', 'https://')):
                url = 'https://' + url
            
            return await self._fetch_page(url)
        
        else:
            return {'success': False, 'error': f"Unknown action: {action}"}
    
    async def _fetch_and_parse_search(self, url: str, query: str) -> Dict[str, Any]:
        """Fetch la página de búsqueda y extrae resultados - IGUAL que fetch normal"""
        
        connector = aiohttp.TCPConnector(ssl=self.ssl_context)
        
        async with aiohttp.ClientSession(connector=connector) as session:
            try:
                # FETCH como a cualquier página
                async with session.get(
                    url,
                    headers={'User-Agent': self.user_agent},
                    timeout=aiohttp.ClientTimeout(total=self.timeout)
                ) as response:
                    
                    if response.status != 200:
                        return {
                            'success': False,
                            'error': f"Search failed: HTTP {response.status}",
                            'data': {'query': query, 'results': []}
                        }
                    
                    # Obtenemos el HTML igual que con fetch_page
                    html = await response.text()
                    
                    # Parseamos el HTML para extraer resultados
                    results = self._extract_search_results(html)
                    
                    return {
                        'success': True,
                        'data': {
                            'query': query,
                            'search_url': url,
                            'results': results[:self.max_results],
                            'count': len(results),
                            'raw_html_length': len(html)  # Para debug
                        }
                    }
                    
            except Exception as e:
                return {
                    'success': False,
                    'error': f"Search fetch error: {str(e)}",
                    'data': {'query': query, 'results': []}
                }
    
    def _extract_search_results(self, html: str) -> List[Dict]:
        """Extrae resultados del HTML de DuckDuckGo Lite con URLs limpias"""
        soup = BeautifulSoup(html, 'html.parser')
        results = []
        
        for table in soup.find_all('table'):
            rows = table.find_all('tr')
            
            for i, row in enumerate(rows):
                links = row.find_all('a')
                
                for link in links:
                    href = link.get('href', '')
                    title = link.get_text(strip=True)
                    
                    if href and title and len(title) > 3:
                        # Limpiar URL (quitar redirect de DDG)
                        if href.startswith('//'):
                            href = 'https:' + href
                        
                        clean_url = self._clean_ddg_url(href)
                        
                        # Buscar snippet
                        snippet = ""
                        if i + 1 < len(rows):
                            next_row = rows[i + 1]
                            snippet_cells = next_row.find_all('td')
                            if snippet_cells:
                                snippet = snippet_cells[0].get_text(strip=True)
                        
                        results.append({
                            'title': title[:150],
                            'url': clean_url,  # URL limpia!
                            'snippet': snippet[:300]
                        })
                        
                        if len(results) >= self.max_results:
                            return results
        
        return results
        
        # Método 2: Si no encontramos con tablas, buscar cualquier enlace relevante
        if not results:
            for link in soup.find_all('a', href=True):
                href = link.get('href', '')
                text = link.get_text(strip=True)
                
                if (href and text and 
                    len(text) > 5 and 
                    href.startswith(('http', '//')) and
                    'duckduckgo.com' not in href and
                    'bing.com' not in href):
                    
                    if href.startswith('//'):
                        href = 'https:' + href
                    
                    results.append({
                        'title': text[:150],
                        'url': href,
                        'snippet': ''
                    })
                    
                    if len(results) >= self.max_results:
                        break
        
        return results
    
    async def _fetch_page(self, url: str) -> Dict[str, Any]:
        """Fetch cualquier página web (tu función original que funciona)"""
        connector = aiohttp.TCPConnector(ssl=self.ssl_context)
        
        async with aiohttp.ClientSession(connector=connector) as session:
            try:
                async with session.get(
                    url,
                    headers={'User-Agent': self.user_agent},
                    timeout=aiohttp.ClientTimeout(total=self.timeout)
                ) as response:
                    if response.status != 200:
                        return {
                            'success': False, 
                            'error': f"HTTP {response.status}",
                            'data': {'url': url, 'status': response.status}
                        }
                    
                    html = await response.text()
                    soup = BeautifulSoup(html, 'html.parser')
                    
                    # Extraer texto legible
                    for script in soup(['script', 'style', 'nav', 'footer']):
                        script.decompose()
                    
                    text = soup.get_text(separator=' ', strip=True)
                    text = re.sub(r'\s+', ' ', text).strip()
                    
                    return {
                        'success': True,
                        'data': {
                            'url': url,
                            'status': response.status,
                            'title': soup.title.string if soup.title else url,
                            'content': text[:3000],
                            'content_length': len(text)
                        }
                    }
                    
            except Exception as e:
                return {'success': False, 'error': str(e)}
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'web',
            'version': '1.2.0',
            'description': 'Fetch and parse web pages including search results',
            'actions': ['search', 'fetch']
        }


# Para compatibilidad
async def execute(query: str = None, action: str = 'search', **kwargs):
    orbit = WebOrbit()
    result = await orbit.execute(query=query, action=action, **kwargs)
    return result