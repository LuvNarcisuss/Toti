"""Prepare native bundle resources in DerivedData from verified HTTPS sources."""
from pathlib import Path, PurePosixPath
import argparse
import json
import os
import shutil
from remote_assets import BUNDLE_FILES, fetch_resources, load_manifest, resource_name, runtime_urls


def generate_catalog(assets: Path, manifest: Path, output: Path) -> int:
    assets, output = assets.resolve(), output.resolve()
    if output.name != 'FlatAssets.xcassets' or output.is_relative_to(assets):
        raise ValueError('Catalog output must be FlatAssets.xcassets outside source Assets')
    records = json.loads(manifest.read_text())['files']
    entries = []
    targets = set()
    # Validate every input first: a missing source must never erase a working catalog.
    for record in records:
        source_name = resource_name(record['source'])
        relative = PurePosixPath(record['path'])
        if Path(source_name).name != source_name or relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Catalog entries must use a flat source and relative output path')
        source = assets / source_name
        if not source.is_file():
            raise FileNotFoundError(source)
        target = output / relative
        if target in targets:
            raise ValueError('Duplicate catalog output: ' + str(relative))
        targets.add(target)
        entries.append((source, target))
    output.mkdir(parents=True, exist_ok=True)
    changed = False
    for source, target in entries:
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)
            changed = True
    for path in sorted(output.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_file() and path not in targets:
            path.unlink()
            changed = True
        elif path.is_dir() and not any(path.iterdir()):
            path.rmdir()
            changed = True
    if changed:
        os.utime(output, None)
    return len(entries)


def prepare_resources(output: Path, catalog: Path, manifest: Path) -> int:
    records = load_manifest(manifest)
    cache = Path(os.environ.get('TOTI_CI_RESOURCE_CACHE', output.parent / 'RemoteAssetCache'))
    count = fetch_resources(records, runtime_urls(records, catalog), cache)
    generate_catalog(cache, catalog, output)
    bundle = output.parent / 'RemoteResources'
    bundle.mkdir(parents=True, exist_ok=True)
    # Remove retired staged agreements when reusing an existing build directory.
    for name in ('TermsOfService.html', 'PrivacyPolicy.html'):
        (bundle / name).unlink(missing_ok=True)
        (cache / name).unlink(missing_ok=True)
    for name in BUNDLE_FILES:
        source, target = cache / name, bundle / name
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copy2(source, target)
    return count


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    count = prepare_resources(args.output, project / 'Configuration/AssetCatalog.json',
                              project / 'Configuration/RemoteAssets.json')
    print(f'Prepared {count} verified remote resources at {args.output.parent}')


if __name__ == '__main__':
    main()
