"""Soporte mínimo para sesiones psql de pruebas PostgreSQL locales desechables."""
import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import time
import uuid


def clean_environment():
    """Pasar a Podman solo variables de entorno necesarias para pruebas locales."""
    allowed = {'PATH', 'HOME', 'USER', 'LOGNAME', 'LANG', 'XDG_RUNTIME_DIR',
               'XDG_CONFIG_HOME', 'XDG_DATA_HOME'}
    return {key: value for key, value in os.environ.items()
            if key in allowed or key.startswith('LC_')}


class BackupStopped(Exception):
    def __init__(self, category, exit_code=None, sqlstate=None, private_error=None):
        super().__init__(category)
        self.category, self.exit_code, self.sqlstate = category, exit_code, sqlstate
        self.private_error = private_error


def classify_error(raw, code, default='COMMAND_FAILED'):
    lower = raw.lower()
    category = default
    for fragment, label in [(b'password authentication failed', 'AUTHENTICATION_REJECTED'),
        (b'certificate verify failed', 'TLS_CA_REJECTED'), (b'does not match host name', 'TLS_HOSTNAME_REJECTED'),
        (b'could not translate host', 'DNS_FAILED'), (b'permission denied', 'PERMISSION_DENIED'),
        (b'out of memory', 'MEMORY_LIMIT'), (b'no space left', 'LOCAL_SPACE_LIMIT')]:
        if fragment in lower:
            category = label
            break
    state = re.search(rb'(?:ERROR|FATAL):\s+([A-Z0-9]{5})\b', raw)
    return BackupStopped(category, code, state.group(1).decode() if state else None, raw)


class ReadSession:
    """Una conexión psql persistente. No registra SQL, resultados ni credenciales."""
    def __init__(self, command, env, error_file, pass_fds=()):
        self.errors = open(error_file, 'xb')
        os.chmod(error_file, 0o600)
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=self.errors, env=env, pass_fds=pass_fds)
        self.buffer = b''
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.error_file = Path(error_file)

    def query(self, query, timeout=180):
        marker = ('CERC_READ_END_' + uuid.uuid4().hex).encode()
        try:
            self.process.stdin.write(query.encode() + b'\n\\echo ' + marker + b'\n')
            self.process.stdin.flush()
        except BrokenPipeError:
            self.process.wait(timeout=5)
            raise classify_error(self.error_file.read_bytes(), self.process.returncode, 'PSQL_SESSION_CLOSED')
        deadline = time.monotonic() + timeout
        while marker + b'\n' not in self.buffer:
            if time.monotonic() >= deadline:
                raise BackupStopped('PSQL_QUERY_TIMEOUT')
            for key, _ in self.selector.select(timeout=min(1, max(0, deadline-time.monotonic()))):
                part = os.read(key.fileobj.fileno(), 65536)
                if not part:
                    self.process.wait(timeout=5)
                    raise classify_error(self.error_file.read_bytes(), self.process.returncode, 'PSQL_READ_FAILED')
                self.buffer += part
        result, self.buffer = self.buffer.split(marker + b'\n', 1)
        return result.decode().strip()

    def json(self, query):
        return json.loads(self.query(query))

    def close(self):
        if self.process.poll() is None:
            try:
                self.process.stdin.write(b'ROLLBACK;\n\\q\n')
                self.process.stdin.flush()
                self.process.wait(timeout=10)
            except (BrokenPipeError, subprocess.TimeoutExpired):
                self.process.kill()
                self.process.wait()
        self.selector.close()
        self.errors.close()
        self.process.stdin.close()
        self.process.stdout.close()
