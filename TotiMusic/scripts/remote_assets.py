"""Download pinned HTTPS resources without depending on the source Assets directory."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tempfile
from urllib.parse import unquote, urlsplit

PROJECT = Path(__file__).resolve().parents[1]
MANIFEST = PROJECT / 'Configuration/RemoteAssets.json'
BUNDLE_FILES = ('TetoRhythm-Display.ttf', 'TetoRhythm-Text.ttf', 'MediaCredits.json')
SUPABASE_BUILD_ASSET_PREFIX = '/storage/v1/object/public/toti-build-assets/'


def resource_name(url: str) -> str:
    parts = urlsplit(url)
    path = unquote(parts.path)
    if parts.hostname == 'gjodhvpzkdnxdjmorjfw.supabase.co' and path.startswith(SUPABASE_BUILD_ASSET_PREFIX):
        path = '/' + path[len(SUPABASE_BUILD_ASSET_PREFIX):]
        for version_prefix in ('/ci-upload-20261030-guest5430/', '/music-authors-20261102/', '/voice-musicians-20261102/'):
            if path.startswith(version_prefix):
                path = '/' + path[len(version_prefix):]
                break
    name = PurePosixPath(path).name
    if (parts.scheme != 'https' or not parts.hostname or parts.username or parts.password
            or parts.query or parts.fragment or '..' in path.split('/')
            or path != '/' + name or not name or '\\' in name):
        raise ValueError('Expected an HTTPS URL with one flat resource filename: ' + url)
    return name


def load_manifest(path: Path = MANIFEST) -> dict:
    records = {}
    names = set()
    for record in json.loads(path.read_text())['files']:
        name = resource_name(record['url'])
        if name.casefold() in names:
            raise ValueError('Duplicate resource filename: ' + name)
        if not re.fullmatch(r'[a-f0-9]{64}', record['sha256']) or not isinstance(record['size'], int) or record['size'] < 0:
            raise ValueError('Invalid integrity metadata: ' + name)
        if 'parts' in record:
            parts = record['parts']
            if not isinstance(parts, list) or not parts or sum(part['size'] for part in parts) != record['size']:
                raise ValueError('Invalid archive parts: ' + name)
            for part in parts:
                resource_name(part['url'])
                if not re.fullmatch(r'[a-f0-9]{64}', part['sha256']) or part['size'] <= 0 or 'parts' in part:
                    raise ValueError('Invalid archive part metadata: ' + name)
        records[record['url']] = record
        names.add(name.casefold())
    return records


def valid_file(path: Path, record: dict) -> bool:
    if not path.is_file() or path.is_symlink() or path.stat().st_size != record['size']:
        return False
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest() == record['sha256']


def fetch_asset(record: dict, cache: Path) -> Path:
    name = resource_name(record['url'])
    target = cache / name
    if valid_file(target, record):
        return target
    cache.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.download-', dir=cache)
    os.close(descriptor)
    temporary = Path(temporary)
    try:
        if record.get('parts'):
            with temporary.open('wb') as destination:
                for part in record['parts']:
                    part_file = fetch_asset(part, cache)
                    with part_file.open('rb') as source:
                        for block in iter(lambda: source.read(1024 * 1024), b''):
                            destination.write(block)
            if not valid_file(temporary, record):
                raise ValueError('Reassembled resource integrity mismatch: ' + record['url'])
            temporary.replace(target)
            return target
        command = ['/usr/bin/curl', '--fail', '--silent', '--show-error', '--location',
                   '--proto', '=https', '--proto-redir', '=https', '--connect-timeout', '15',
                   '--max-time', '180', '--retry', '2', '--output', str(temporary), record['url']]
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
        except (OSError, subprocess.CalledProcessError) as error:
            raise RuntimeError('Resource download failed: ' + record['url'] + '\n' + str(getattr(error, 'stderr', '') or error)) from error
        if not valid_file(temporary, record):
            raise ValueError('Resource integrity mismatch: ' + record['url'])
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    return target


def fetch_resources(records: dict, urls, cache: Path) -> int:
    selected = [records[url] for url in dict.fromkeys(urls)]
    with ThreadPoolExecutor(max_workers=8) as pool:
        list(pool.map(lambda record: fetch_asset(record, cache), selected))
    return len(selected)


def runtime_urls(records: dict, catalog: Path) -> list:
    urls = [item['source'] for item in json.loads(catalog.read_text())['files']]
    by_name = {resource_name(url): url for url in records}
    return list(dict.fromkeys(urls + [by_name[name] for name in BUNDLE_FILES]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--all', action='store_true', help='Also download source artwork and archived media.')
    args = parser.parse_args()
    records = load_manifest()
    urls = list(records) if args.all else runtime_urls(records, PROJECT / 'Configuration/AssetCatalog.json')
    count = fetch_resources(records, urls, args.cache)
    print(f'Verified {count} remote resources in {args.cache}')


if __name__ == '__main__':
    main()
