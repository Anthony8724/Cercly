#!/usr/bin/env python3
"""Regresión del contrato de archivos CLI; sin contenedores ni conexiones."""
from pathlib import Path
import tempfile
import unittest
from preparar_preflight_staging import runtime_files


class RuntimeFilesTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='cercly-preflight-files-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'supabase/templates').mkdir(parents=True)

    def config(self, value):
        (self.root / 'supabase/config.toml').write_text(
            '[auth.email.template.magic_link]\ncontent_path = "' + value + '"\n')

    def test_missing_template_is_rejected_before_cli(self):
        self.config('./supabase/templates/magic_link_otp.html')
        with self.assertRaisesRegex(ValueError, 'Falta una plantilla'):
            runtime_files(self.root)

    def test_config_and_template_are_included(self):
        self.config('./supabase/templates/magic_link_otp.html')
        (self.root / 'supabase/templates/magic_link_otp.html').write_text('{{ .Token }}')
        self.assertEqual(set(runtime_files(self.root)), {
            'supabase/config.toml', 'supabase/templates/magic_link_otp.html'})

    def test_internal_alias_keeps_the_configured_destination(self):
        self.config('./supabase/templates/alias.html')
        template = self.root / 'supabase/templates/source.html'
        template.write_text('{{ .Token }}')
        (self.root / 'supabase/templates/alias.html').symlink_to(template)
        files = runtime_files(self.root)
        self.assertEqual(files['supabase/templates/alias.html'], template)
        self.assertNotIn('supabase/templates/source.html', files)

    def test_external_paths_are_rejected(self):
        for path in ('/tmp/private.html', '../private.html', './.env'):
            with self.subTest(path=path):
                self.config(path)
                with self.assertRaises(ValueError):
                    runtime_files(self.root)

    def test_config_symlink_cannot_copy_external_private_file(self):
        private = self.root / 'private.toml'
        private.write_text('[auth]\n')
        (self.root / 'supabase/config.toml').symlink_to(private)
        with self.assertRaises(ValueError):
            runtime_files(self.root)

    def test_symlink_cannot_escape_template_directory(self):
        self.config('./supabase/templates/magic_link_otp.html')
        (self.root / 'private.html').write_text('not a template')
        (self.root / 'supabase/templates/magic_link_otp.html').symlink_to(self.root / 'private.html')
        with self.assertRaises(ValueError):
            runtime_files(self.root)


if __name__ == '__main__':
    unittest.main(verbosity=2)
