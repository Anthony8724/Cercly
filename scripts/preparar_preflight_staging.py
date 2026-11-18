#!/usr/bin/env python3
"""Copia local reproducible para STAGING. No usa red, CLI, secretos ni .temp."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tomllib

ROOT = Path(__file__).resolve().parents[1]
REF = 'dlajxviqhkdcqnmczhvr'


def runtime_files(root):
    """Contrato mínimo del CLI: config y plantillas declaradas, nunca secretos.

    No copia .env, .temp, certificados ni rutas externas. Fallar antes de crear
    la copia si una plantilla falta evita descubrirlo durante el despliegue.
    """
    root = root.resolve()
    config = root / 'supabase/config.toml'
    if config.is_symlink() or config.resolve().parent != root / 'supabase':
        raise ValueError('config.toml debe permanecer dentro de supabase sin enlaces externos')
    files = {'supabase/config.toml': config}

    def visit(value):
        if not isinstance(value, dict):
            return
        for key, item in value.items():
            if key == 'content_path':
                if not isinstance(item, str):
                    raise ValueError('content_path debe ser una ruta de plantilla')
                relative = Path(item)
                candidate = (root / relative).resolve()
                templates = root / 'supabase/templates'
                if (relative.is_absolute() or '..' in relative.parts
                        or Path('supabase/templates') not in relative.parents
                        or templates not in candidate.parents or candidate.suffix != '.html'):
                    raise ValueError('Solo se permiten plantillas HTML dentro de supabase/templates')
                if not candidate.is_file():
                    raise ValueError('Falta una plantilla referenciada por config.toml: ' + str(relative))
                files[str(relative)] = candidate
            elif isinstance(item, dict):
                visit(item)

    visit(tomllib.loads(config.read_text()).get('auth', {}))
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dest', required=True, type=Path,
                        help='Directorio NUEVO fuera del repositorio')
    args = parser.parse_args()
    dest = args.dest.expanduser().resolve()
    if dest == ROOT or ROOT in dest.parents or dest.exists():
        raise SystemExit('El destino debe ser nuevo y estar fuera del repositorio')
    manifest = json.loads((ROOT / 'docs/staging_migration_manifest_20261107.json').read_text())
    if manifest['project_ref'] != REF or len(manifest['historical']) != 24:
        raise SystemExit('Identidad o historial inesperados')
    expected = {x['source_file'] for x in manifest['historical'] + manifest['pending']}
    actual = {x.name for x in (ROOT / 'supabase/migrations').glob('*.sql')}
    if actual != expected or len(manifest['pending']) != 2:
        raise SystemExit('Hay migraciones no revisadas o falta una migración')
    copies = []
    for entry in manifest['historical'] + manifest['pending']:
        source = ROOT / 'supabase/migrations' / entry['source_file']
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry['source_sha256']:
            raise SystemExit(f'Hash distinto: {source.name}; requiere nueva revisión')
        version = entry.get('remote_version', source.name.split('_')[0])
        name = source.name
        if version != source.name.split('_')[0]:
            name = version + '_' + entry['remote_name'] + '.sql'
        copies.append((source, name))
    if len({x[1] for x in copies}) != 26:
        raise SystemExit('Colisión de nombres en la reconciliación')
    runtime = runtime_files(ROOT)
    # Crear solo tras validar todos los archivos; sin sobrescribir un destino.
    dest.mkdir(mode=0o700, parents=True)
    (dest / 'supabase/migrations').mkdir(parents=True)
    for relative, source in runtime.items():
        target = dest / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    for source, name in copies:
        shutil.copy2(source, dest / 'supabase/migrations' / name)
    manifest['source_commit'] = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    manifest['preflight_runtime_files'] = {
        relative: hashlib.sha256(source.read_bytes()).hexdigest()
        for relative, source in runtime.items()
    }
    (dest / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Preflight local: {dest}')
    print('24 históricas conciliadas; 2 pendientes; sin enlace ni datos remotos')


if __name__ == '__main__':
    main()
