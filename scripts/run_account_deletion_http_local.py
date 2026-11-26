#!/usr/bin/env python3
"""Arranca únicamente el servidor HTTP local del ensayo y lo detiene al salir."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
from urllib.error import HTTPError
from urllib.request import urlopen

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--credentials', type=Path, required=True)
p.add_argument('--report', type=Path, required=True)
args = p.parse_args()
assert args.credentials.resolve().is_relative_to('/tmp')
assert args.credentials.stat().st_mode & 0o077 == 0
config = json.loads(args.credentials.read_text())
assert config['API_URL'] == 'http://127.0.0.1:56431'
with socket.socket() as probe:
    probe.bind(('127.0.0.1', 56435))
root = Path(__file__).resolve().parents[1]
env = dict(os.environ, SUPABASE_URL=config['API_URL'], SUPABASE_ANON_KEY=config['ANON_KEY'], SUPABASE_SERVICE_ROLE_KEY=config['SERVICE_ROLE_KEY'])
with tempfile.TemporaryFile() as log:
    server = subprocess.Popen(['deno', 'run', '--no-config', '--cached-only', '--allow-net=127.0.0.1:56431,127.0.0.1:56435', '--allow-env=SUPABASE_URL,SUPABASE_ANON_KEY,SUPABASE_SERVICE_ROLE_KEY', str(root/'scripts/serve_account_deletion_http_local.ts')], env=env, stdout=log, stderr=log)
    try:
        for _ in range(100):
            if server.poll() is not None:
                raise RuntimeError('No inició el handler local; comprobar caché Deno/SDK y permisos')
            try:
                urlopen('http://127.0.0.1:56435', timeout=1)
            except HTTPError as response:
                if response.code == 405:
                    break
            except OSError:
                pass
            time.sleep(0.1)
        else:
            raise RuntimeError('Timeout del handler local')
        subprocess.run(['python3', str(root/'scripts/test_account_deletion_http_local.py'), '--credentials', str(args.credentials), '--report', str(args.report)], check=True)
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
