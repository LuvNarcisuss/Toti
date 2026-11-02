#!/usr/bin/env python3
"""Restore every pinned public build resource into a disposable CI cache."""
from pathlib import Path
import os

from remote_assets import fetch_resources, load_manifest


def main() -> None:
    project = Path(__file__).resolve().parents[1]
    cache = Path(os.environ.get('TOTI_CI_RESOURCE_CACHE', project.parent / '.ci' / 'toti-assets'))
    records = load_manifest(project / 'Configuration/RemoteAssets.json')
    count = fetch_resources(records, records.keys(), cache)
    print(f"Restored and verified {count} pinned build resources in {cache}")


if __name__ == '__main__':
    main()
