"""Recreate Xcode's catalog in DerivedData from the flat, authoritative Assets folder."""
from pathlib import Path, PurePosixPath
import argparse
import json
import os
import shutil


def generate_catalog(assets: Path, manifest: Path, output: Path) -> int:
    assets, output = assets.resolve(), output.resolve()
    if output.name != 'FlatAssets.xcassets' or output.is_relative_to(assets):
        raise ValueError('Catalog output must be FlatAssets.xcassets outside source Assets')
    records = json.loads(manifest.read_text())['files']
    entries = []
    targets = set()
    # Validate every input first: a missing source must never erase a working catalog.
    for record in records:
        source_name = record['source']
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


def main():
    project = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    count = generate_catalog(project.parent / 'Assets',
                             project / 'Configuration/AssetCatalog.json', args.output)
    print(f'Prepared {count} catalog files from flat Assets at {args.output}')


if __name__ == '__main__':
    main()
