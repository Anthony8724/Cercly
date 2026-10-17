"""Read only Auth settings; never emits URLs, API keys, or response bodies."""
import json
from pathlib import Path
import sys
import urllib.request
import urllib.error

config = json.loads(Path('config/supabase.local.json').read_text())
url = config.get('SUPABASE_URL', '').rstrip('/')
key = config.get('SUPABASE_PUBLISHABLE_KEY', '')
if not url.startswith(('https://', 'http://localhost:', 'http://127.0.0.1:')):
    sys.exit('No se consultó: URL de configuración no válida.')
request = urllib.request.Request(url + '/auth/v1/settings', headers={'apikey': key})
try:
    with urllib.request.urlopen(request, timeout=15) as response:
        data = json.load(response)
except (urllib.error.URLError, TimeoutError):
    sys.exit('No se pudo consultar Auth settings; no se modificó nada.')
external = data.get('external', {})
for provider in ('email', 'google', 'azure', 'facebook', 'phone'):
    print(f'{provider}: enabled={external.get(provider, "unknown")}')
print('Esta lectura no valida credenciales OAuth, entrega SMS ni login completo.')
