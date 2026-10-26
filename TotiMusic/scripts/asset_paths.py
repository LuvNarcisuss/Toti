"""Resolve historical resource identities to files in the flat Assets folder."""
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ASSETS = PROJECT.parent / 'Assets'
LAYOUT = json.loads((PROJECT / 'Configuration/AssetLayout.json').read_text())['files']


def asset_file(relative: str) -> Path:
    if relative in LAYOUT:
        return ASSETS / LAYOUT[relative]
    # New source downloads/review frames use the same collision-free prefix convention.
    parts = Path(relative).parts
    if parts and parts[0] in {'Design', 'Screenshots'} and '..' not in parts:
        return ASSETS / '__'.join(parts)
    if len(parts) == 2 and parts[0] == 'MusicMedia':
        return ASSETS / parts[1]
    raise KeyError('Register the resource in Configuration/AssetLayout.json: ' + relative)
