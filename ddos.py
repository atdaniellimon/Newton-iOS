print("INICIO DE PRUEBA", flush=True)
import urllib.request
try:
    response = urllib.request.urlopen("http://localhost:8080/", timeout=2)
    print(f"RESPUESTA: {response.status}", flush=True)
except Exception as e:
    print(f"EXCEPCIÓN CAPTURADA CORRECTAMENTE: {type(e).__name__}", flush=True)
