import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

GUARD = Path(__file__).resolve().parents[1] / 'check_git_media.py'


class GitMediaGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Resource Test')
        self.git('config', 'user.email', 'resource-test@example.invalid')

    def git(self, *arguments):
        return subprocess.check_output(['git', *arguments], cwd=self.repo, text=True).strip()

    def commit(self, name, data):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        self.git('add', '--', name)
        self.git('commit', '-qm', 'Add fixture')

    def check(self, *args, input=None):
        return subprocess.run([sys.executable, str(GUARD), *args], cwd=self.repo,
                              input=input, text=True, capture_output=True)

    def test_allows_small_source_history(self):
        self.commit('main.swift', b'import UIKit\n')
        self.assertEqual(self.check('HEAD').returncode, 0)

    def test_blocks_media_even_when_deleted_from_latest_commit(self):
        self.commit('docs/photo.PNG', b'picture')
        self.git('rm', 'docs/photo.PNG')
        self.git('commit', '-qm', 'Remove fixture')
        result = self.check('HEAD')
        self.assertEqual(result.returncode, 1)
        self.assertIn('docs/photo.PNG', result.stdout)

    def test_blocks_assets_metadata_and_oversized_objects(self):
        self.commit('Assets/catalog.json', b'{}')
        self.commit('archive.bin', b'x' * (5 * 1024 * 1024 + 1))
        result = self.check('HEAD')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Assets/catalog.json', result.stdout)
        self.assertIn('archive.bin', result.stdout)

    def test_blocks_renamed_image_without_media_extension(self):
        self.commit('content.dat', b'\x89PNG\r\n\x1a\n' + b'data')
        self.assertEqual(self.check('HEAD').returncode, 1)

    def test_blocks_assets_path_before_an_unchanged_rename(self):
        self.commit('Assets/catalog.json', b'{"version":1}')
        (self.repo / 'Configuration').mkdir()
        self.git('mv', 'Assets/catalog.json', 'Configuration/catalog.json')
        self.git('commit', '-qm', 'Rename unchanged fixture')
        self.assertEqual(self.check('HEAD').returncode, 1)

    def test_blocks_media_alias_sharing_an_allowed_blob(self):
        content = b'<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg"/>'
        self.commit('0-document.xml', content)
        self.commit('z-image.svg', content)
        result = self.check('HEAD')
        self.assertEqual(result.returncode, 1)
        self.assertIn('z-image.svg', result.stdout)

    def test_push_checks_only_the_refs_being_sent(self):
        self.commit('main.swift', b'import UIKit\n')
        good = self.git('rev-parse', 'HEAD')
        self.git('checkout', '-qb', 'media-work')
        self.commit('image.png', b'image')
        bad = self.git('rev-parse', 'HEAD')
        zeros = '0' * 40
        good_input = f'refs/heads/main {good} refs/heads/main {zeros}\n'
        self.assertEqual(self.check('--pre-push', input=good_input).returncode, 0)
        bad_input = f'refs/heads/media-work {bad} refs/heads/media-work {zeros}\n'
        self.assertEqual(self.check('--pre-push', input=bad_input).returncode, 1)
        self.assertEqual(self.check('--pre-push', input=f'(delete) {zeros} refs/heads/media-work {bad}\n').returncode, 0)


if __name__ == '__main__':
    unittest.main()
