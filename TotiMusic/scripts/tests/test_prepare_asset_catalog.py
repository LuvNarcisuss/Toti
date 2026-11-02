import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from prepare_asset_catalog import generate_catalog


class CatalogGenerationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.assets = self.root / 'Assets'
        self.assets.mkdir()
        self.output = self.root / 'DerivedData' / 'FlatAssets.xcassets'
        self.manifest = self.root / 'catalog.json'
        self.entries = [
            {'source': 'Catalog-Contents.json', 'path': 'Contents.json'},
            {'source': 'Catalog-Studio.json', 'path': 'Studio.imageset/Contents.json'},
            {'source': 'Studio.png', 'path': 'Studio.imageset/image.png'},
            {'source': 'Catalog-Launch.json', 'path': 'Launch.colorset/Contents.json'},
        ]
        (self.assets / 'Catalog-Contents.json').write_text('{"info":{"version":1}}')
        (self.assets / 'Catalog-Studio.json').write_text('{"images":[{"filename":"image.png","idiom":"universal"}]}')
        (self.assets / 'Catalog-Launch.json').write_text('{"colors":[]}')
        (self.assets / 'Studio.png').write_bytes(b'original-image-bytes')
        for entry in self.entries:
            entry['source'] = 'https://assets.example.com/' + entry['source']
        self.save_manifest()

    def save_manifest(self):
        self.manifest.write_text(json.dumps({'schemaVersion': 1, 'files': self.entries}))

    def generate(self):
        return generate_catalog(self.assets, self.manifest, self.output)

    def test_preserves_catalog_names_metadata_and_flat_source_bytes(self):
        self.generate()
        for entry in self.entries:
            self.assertEqual((self.assets / entry['source'].rsplit('/', 1)[-1]).read_bytes(),
                             (self.output / entry['path']).read_bytes())
        self.assertFalse(any(p.is_dir() for p in self.assets.iterdir()))

    def test_rebuild_refreshes_changed_images_and_removes_stale_outputs(self):
        self.generate()
        (self.assets / 'Studio.png').write_bytes(b'updated-image-bytes')
        self.entries = self.entries[:-1]
        self.save_manifest()
        self.generate()
        self.assertEqual((self.output / 'Studio.imageset/image.png').read_bytes(), b'updated-image-bytes')
        self.assertFalse((self.output / 'Launch.colorset').exists())

    def test_missing_source_fails_before_changing_previous_output(self):
        self.generate()
        (self.assets / 'Studio.png').unlink()
        with self.assertRaises(FileNotFoundError):
            self.generate()
        self.assertEqual((self.output / 'Studio.imageset/image.png').read_bytes(), b'original-image-bytes')

    def test_output_cannot_be_written_inside_source_assets(self):
        with self.assertRaises(ValueError):
            generate_catalog(self.assets, self.manifest, self.assets / 'FlatAssets.xcassets')


if __name__ == '__main__':
    unittest.main()
