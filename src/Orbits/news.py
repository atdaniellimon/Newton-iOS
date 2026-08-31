# src/Orbits/news.py
"""
News Orbit - Fetch latest news using NewsAPI (free tier)
With improved parameter definitions for tool calling
"""

import aiohttp
import json
import os
from typing import Dict, Any, List

DEFAULT_API_KEY = "d3e9b8c1f4a6b7c8d9e0f1a2b3c4d5e6"  # Demo key, replace with your own

class NewsOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.api_key = self.config.get('api_key', DEFAULT_API_KEY)
        self.country = self.config.get('country', 'us')
        self.page_size = self.config.get('page_size', 5)
        self.timeout = self.config.get('timeout', 10)
    
    async def execute(self, query: str = None, category: str = None, **kwargs) -> Dict[str, Any]:
        """
        Fetch news headlines.
        query: search term (optional)
        category: business, entertainment, general, health, science, sports, technology
        """
        base_url = "https://newsapi.org/v2/top-headlines"
        params = {
            'apiKey': self.api_key,
            'pageSize': self.page_size,
            'country': self.country
        }
        
        if category:
            params['category'] = category
        if query:
            params['q'] = query
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(base_url, params=params, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                    if resp.status != 200:
                        return {
                            'success': False,
                            'error': f"News API returned {resp.status}",
                            'data': {
                                'articles': [],
                                'message': 'Could not fetch news, please check API key'
                            }
                        }
                    
                    data = await resp.json()
                    articles = data.get('articles', [])
                    
                    # Format results
                    results = []
                    for article in articles[:self.page_size]:
                        results.append({
                            'title': article.get('title', ''),
                            'description': article.get('description', ''),
                            'url': article.get('url', ''),
                            'source': article.get('source', {}).get('name', ''),
                            'publishedAt': article.get('publishedAt', '')
                        })
                    
                    return {
                        'success': True,
                        'data': {
                            'total': len(results),
                            'query': query or category or 'top headlines',
                            'articles': results
                        }
                    }
                    
        except Exception as e:
            return {
                'success': False,
                'error': f"Failed to fetch news: {str(e)}"
            }
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'news',
            'version': '1.0.0',
            'description': 'Fetch latest news headlines',
            'parameters': {
                'query': {
                    'type': 'string',
                    'description': 'Search term for news',
                    'required': False
                },
                'category': {
                    'type': 'string',
                    'description': 'News category: business, entertainment, general, health, science, sports, technology',
                    'enum': ['business', 'entertainment', 'general', 'health', 'science', 'sports', 'technology'],
                    'required': False
                }
            }
        }


async def execute(query: str = None, category: str = None, **kwargs):
    orbit = NewsOrbit()
    return await orbit.execute(query=query, category=category, **kwargs)