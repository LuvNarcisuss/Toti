import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import remote_assets


class RemoteAssetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cache = Path(self.temp.name) / 'cache'
        self.record = {'url': 'https://assets.example.com/Portrait.png',
                       'sha256': hashlib.sha256(b'portrait').hexdigest(), 'size': 8}

    def download(self, command, **kwargs):
        Path(command[command.index('--output') + 1]).write_bytes(b'portrait')
        return subprocess.CompletedProcess(command, 0, '', '')

    def test_downloaded_bytes_are_cached_and_reused_offline(self):
        with patch('remote_assets.subprocess.run', side_effect=self.download):
            result = remote_assets.fetch_asset(self.record, self.cache)
        self.assertEqual(result.read_bytes(), b'portrait')
        with patch('remote_assets.subprocess.run', side_effect=OSError('offline')):
            self.assertEqual(remote_assets.fetch_asset(self.record, self.cache).read_bytes(), b'portrait')

    def test_corrupt_cache_is_repaired(self):
        self.cache.mkdir()
        (self.cache / 'Portrait.png').write_bytes(b'broken')
        with patch('remote_assets.subprocess.run', side_effect=self.download):
            self.assertEqual(remote_assets.fetch_asset(self.record, self.cache).read_bytes(), b'portrait')

    def test_hash_mismatch_does_not_publish_or_overwrite_cached_file(self):
        self.cache.mkdir()
        old = self.cache / 'Portrait.png'
        old.write_bytes(b'prior-version')
        self.record['sha256'] = '0' * 64
        with patch('remote_assets.subprocess.run', side_effect=self.download):
            with self.assertRaisesRegex(ValueError, 'integrity'):
                remote_assets.fetch_asset(self.record, self.cache)
        self.assertEqual(old.read_bytes(), b'prior-version')
        self.assertEqual(list(self.cache.iterdir()), [old])

    def test_http_failure_never_publishes_partial_download(self):
        def fail(command, **kwargs):
            Path(command[command.index('--output') + 1]).write_bytes(b'partial')
            raise subprocess.CalledProcessError(22, command, stderr='HTTP 404')
        with patch('remote_assets.subprocess.run', side_effect=fail):
            with self.assertRaisesRegex(RuntimeError, 'Portrait.png'):
                remote_assets.fetch_asset(self.record, self.cache)
        self.assertFalse((self.cache / 'Portrait.png').exists())
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_rejects_unsafe_resource_urls_before_writing(self):
        for url in ['http://assets.example.com/a.png', 'file:///a.png',
                    'https://assets.example.com/../a.png',
                    'https://assets.example.com/%2Fescape.png',
                    'https://assets.example.com/a.png?token=secret']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                remote_assets.fetch_asset(dict(self.record, url=url), self.cache)
        self.assertFalse(self.cache.exists())

    def test_accepts_public_toti_supabase_object_urls(self):
        url = ('https://gjodhvpzkdnxdjmorjfw.supabase.co/storage/v1/object/public/'
               'toti-build-assets/Portrait.png')
        self.assertEqual(remote_assets.resource_name(url), 'Portrait.png')

    def test_rejects_duplicate_cache_names_in_manifest(self):
        manifest = Path(self.temp.name) / 'manifest.json'
        manifest.write_text(json.dumps({'files': [self.record,
            dict(self.record, url='https://other.example.com/Portrait.png')]}))
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            remote_assets.load_manifest(manifest)

class BuildPreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / 'RemoteAssetCache'
        self.cache.mkdir()
        self.output = self.root / 'FlatAssets.xcassets'
        self.manifest = self.root / 'remote.json'
        self.catalog = self.root / 'catalog.json'
        self.records = []
        for name in (*remote_assets.BUNDLE_FILES, 'Catalog-Contents.json', 'Picture.png'):
            data = ('contents-' + name).encode()
            (self.cache / name).write_bytes(data)
            self.records.append({'url': 'https://assets.example.com/' + name,
                                 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest()})
        self.manifest.write_text(json.dumps({'files': self.records}))
        self.catalog.write_text(json.dumps({'files': [
            {'source': 'https://assets.example.com/Catalog-Contents.json', 'path': 'Contents.json'},
            {'source': 'https://assets.example.com/Picture.png', 'path': 'Picture.imageset/Picture.png'}]}))

    def test_stages_catalog_and_loose_files_without_source_assets(self):
        from prepare_asset_catalog import prepare_resources
        bundle = self.root / 'RemoteResources'
        bundle.mkdir()
        for name in ('PrivacyPolicy.html', 'TermsOfService.html'):
            (bundle / name).write_text('Retired agreement')
            (self.cache / name).write_text('Retired agreement')
        with patch('remote_assets.subprocess.run', side_effect=OSError('offline')):
            prepare_resources(self.output, self.catalog, self.manifest)
        self.assertEqual((self.output / 'Picture.imageset/Picture.png').read_bytes(), b'contents-Picture.png')
        self.assertEqual((bundle / 'MediaCredits.json').read_bytes(), b'contents-MediaCredits.json')
        for name in ('PrivacyPolicy.html', 'TermsOfService.html'):
            self.assertFalse((bundle / name).exists())
            self.assertFalse((self.cache / name).exists())
        self.assertFalse((self.root / 'Assets').exists())

    def test_failed_download_preserves_previous_catalog_and_bundle(self):
        from prepare_asset_catalog import prepare_resources
        prepare_resources(self.output, self.catalog, self.manifest)
        (self.cache / 'Picture.png').write_bytes(b'broken')
        self.records[0]['sha256'] = hashlib.sha256(b'new-font').hexdigest()
        self.records[0]['size'] = 8
        self.manifest.write_text(json.dumps({'files': self.records}))
        with patch('remote_assets.subprocess.run', side_effect=OSError('offline')):
            with self.assertRaises(RuntimeError):
                prepare_resources(self.output, self.catalog, self.manifest)
        self.assertEqual((self.output / 'Picture.imageset/Picture.png').read_bytes(), b'contents-Picture.png')
        self.assertEqual((self.root / 'RemoteResources/TetoRhythm-Display.ttf').read_bytes(), b'contents-TetoRhythm-Display.ttf')


if __name__ == '__main__':
    unittest.main()
