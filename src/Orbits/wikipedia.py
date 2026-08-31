# src/Orbits/wikipedia.py
"""
Wikipedia Orbit - Fetch summaries and content from Wikipedia
"""

import aiohttp
import json
from typing import Dict, Any, List

class WikipediaOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.lang = self.config.get('lang', 'en')
        self.timeout = self.config.get('timeout', 10)
    
    async def execute(self, query: str = None, action: str = 'summary', **kwargs) -> Dict[str, Any]:
        """
        Fetch Wikipedia content.
        action: 'summary' (brief), 'extract' (full), 'search' (list of titles)
        """
        if not query and action != 'search':
            return {'success': False, 'error': "Missing 'query' parameter"}
        
        base_url = f"https://{self.lang}.wikipedia.org/w/api.php"
        
        try:
            async with aiohttp.ClientSession() as session:
                if action == 'summary':
                    # Use the summary endpoint (simpler)
                    summary_url = f"https://{self.lang}.wikipedia.org/api/rest_v1/page/summary/{query.replace(' ', '_')}"
                    async with session.get(summary_url, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                        if resp.status != 200:
                            return {
                                'success': False,
                                'error': f"Wikipedia returned {resp.status}",
                                'data': {'message': 'Page not found or invalid query'}
                            }
                        data = await resp.json()
                        return {
                            'success': True,
                            'data': {
                                'title': data.get('title', query),
                                'extract': data.get('extract', ''),
                                'url': data.get('content_urls', {}).get('desktop', {}).get('page', ''),
                                'thumbnail': data.get('thumbnail', {}).get('source', '')
                            }
                        }
                
                elif action == 'extract':
                    # Use action=query&prop=extracts
                    params = {
                        'action': 'query',
                        'format': 'json',
                        'titles': query,
                        'prop': 'extracts',
                        'exintro': True,
                        'explaintext': True,
                        'redirects': 1
                    }
                    async with session.get(base_url, params=params, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                        if resp.status != 200:
                            return {'success': False, 'error': f"Wikipedia API returned {resp.status}"}
                        data = await resp.json()
                        pages = data.get('query', {}).get('pages', {})
                        if not pages:
                            return {'success': False, 'error': 'No pages found'}
                        page = next(iter(pages.values()))
                        if 'missing' in page:
                            return {'success': False, 'error': 'Page not found'}
                        return {
                            'success': True,
                            'data': {
                                'title': page.get('title', query),
                                'extract': page.get('extract', ''),
                                'pageid': page.get('pageid')
                            }
                        }
                
                elif action == 'search':
                    params = {
                        'action': 'query',
                        'format': 'json',
                        'list': 'search',
                        'srsearch': query,
                        'srlimit': 5
                    }
                    async with session.get(base_url, params=params, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                        if resp.status != 200:
                            return {'success': False, 'error': f"Wikipedia API returned {resp.status}"}
                        data = await resp.json()
                        results = data.get('query', {}).get('search', [])
                        titles = [r.get('title') for r in results if 'title' in r]
                        return {
                            'success': True,
                            'data': {
                                'query': query,
                                'results': titles,
                                'count': len(titles)
                            }
                        }
                
                else:
                    return {'success': False, 'error': f"Unknown action: {action}"}
                    
        except Exception as e:
            return {'success': False, 'error': f"Failed to fetch Wikipedia: {str(e)}"}
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'wikipedia',
            'version': '1.0.0',
            'description': 'Fetch Wikipedia articles and summaries',
            'parameters': {
                'query': 'string (search term or page title)',
                'action': 'string (summary, extract, search)'
            }
        }


async def execute(query: str = None, action: str = 'summary', **kwargs):
    orbit = WikipediaOrbit()
    return await orbit.execute(query=query, action=action, **kwargs)