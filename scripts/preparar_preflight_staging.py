#!/usr/bin/env python3
"""Copia local reproducible para STAGING. No usa red, CLI, secretos ni .temp."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REF = 'dlajxviqhkdcqnmczhvr'


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
    # Crear solo tras validar todos los archivos; sin sobrescribir un destino.
    dest.mkdir(mode=0o700, parents=True)
    (dest / 'supabase/migrations').mkdir(parents=True)
    shutil.copy2(ROOT / 'supabase/config.toml', dest / 'supabase/config.toml')
    for source, name in copies:
        shutil.copy2(source, dest / 'supabase/migrations' / name)
    manifest['source_commit'] = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    (dest / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Preflight local: {dest}')
    print('24 históricas conciliadas; 2 pendientes; sin enlace ni datos remotos')


if __name__ == '__main__':
    main()
