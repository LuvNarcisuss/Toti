"""Resolve resource identities to verified remote inputs and editable tool outputs."""
import json
import os
from pathlib import Path
from remote_assets import fetch_asset, load_manifest, resource_name

PROJECT = Path(__file__).resolve().parents[1]
WORKSPACE = Path(os.environ.get('TOTI_RESOURCE_WORKSPACE', PROJECT.parent / 'build/ResourceTools'))
CACHE = WORKSPACE / 'cache'
OUTPUT = WORKSPACE / 'output'
LAYOUT = json.loads((PROJECT / 'Configuration/AssetLayout.json').read_text())['files']
MANIFEST = load_manifest()
BASE_URL = json.loads((PROJECT / 'Configuration/RemoteAssets.json').read_text())['baseURL']


def asset_url(relative: str) -> str:
    if relative in LAYOUT:
        return LAYOUT[relative]
    parts = Path(relative).parts
    if parts and parts[0] in {'Design', 'Screenshots'} and '..' not in parts:
        return BASE_URL + '__'.join(parts)
    if len(parts) == 2 and parts[0] == 'MusicMedia' and parts[1] != '..':
        return BASE_URL + parts[1]
    raise KeyError('Register the resource in Configuration/AssetLayout.json: ' + relative)


def asset_output(relative: str) -> Path:
    path = OUTPUT / resource_name(asset_url(relative))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    return path


def asset_file(relative: str) -> Path:
    url = asset_url(relative)
    edited = OUTPUT / resource_name(url)
    if edited.is_file():
        return edited
    return fetch_asset(MANIFEST[url], CACHE)
