# src/Orbits/weather.py
"""
Weather Orbit - Get current weather using wttr.in (free, no API key)
With improved parameter definitions for tool calling
"""

import aiohttp
import json
from typing import Dict, Any

class WeatherOrbit:
    def __init__(self, config: dict = None):
        self.config = config or {}
        self.default_city = self.config.get('default_city', 'London')
        self.timeout = self.config.get('timeout', 10)
    
    async def execute(self, city: str = None, units: str = 'metric', **kwargs) -> Dict[str, Any]:
        """
        Get weather for a city.
        units: 'metric' (Celsius) or 'imperial' (Fahrenheit)
        """
        if not city:
            city = self.default_city
        
        # Use wttr.in API (no key required)
        url = f"https://wttr.in/{city}?format=j1"
        if units == 'imperial':
            url += '&u'
        
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=aiohttp.ClientTimeout(total=self.timeout)) as resp:
                    if resp.status != 200:
                        return {
                            'success': False,
                            'error': f"Weather API returned {resp.status}"
                        }
                    
                    data = await resp.json()
                    
                    # Parse wttr.in response
                    current = data.get('current_condition', [{}])[0]
                    location = data.get('nearest_area', [{}])[0]
                    
                    temp_c = current.get('temp_C', 'N/A')
                    temp_f = current.get('temp_F', 'N/A')
                    humidity = current.get('humidity', 'N/A')
                    wind_speed = current.get('windspeedKmph', 'N/A')
                    weather_desc = current.get('weatherDesc', [{}])[0].get('value', 'Unknown')
                    city_name = location.get('areaName', [{}])[0].get('value', city)
                    country = location.get('country', [{}])[0].get('value', '')
                    
                    result = {
                        'city': city_name,
                        'country': country,
                        'condition': weather_desc,
                        'temperature_c': temp_c,
                        'temperature_f': temp_f,
                        'humidity': humidity,
                        'wind_speed_kmh': wind_speed,
                        'units': units
                    }
                    
                    return {
                        'success': True,
                        'data': result
                    }
                    
        except Exception as e:
            return {
                'success': False,
                'error': f"Failed to fetch weather: {str(e)}"
            }
    
    def get_capabilities(self) -> dict:
        return {
            'name': 'weather',
            'version': '1.0.0',
            'description': 'Get current weather for any city',
            'parameters': {
                'city': {
                    'type': 'string',
                    'description': 'City name (e.g., "London", "Madrid", "Tokyo")',
                    'required': True
                },
                'units': {
                    'type': 'string',
                    'description': 'Units system: "metric" (Celsius) or "imperial" (Fahrenheit)',
                    'enum': ['metric', 'imperial'],
                    'default': 'metric',
                    'required': False
                }
            }
        }


async def execute(city: str = None, units: str = 'metric', **kwargs):
    orbit = WeatherOrbit()
    return await orbit.execute(city=city, units=units, **kwargs)