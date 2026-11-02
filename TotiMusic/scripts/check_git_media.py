#!/usr/bin/env python3
"""Reject source media and large blobs from the entire history of refs being pushed."""
import argparse
from pathlib import PurePosixPath
import subprocess
import sys

MAX_BYTES = 5 * 1024 * 1024
MEDIA = set('.png .jpg .jpeg .gif .webp .svg .heic .heif .avif .bmp .tiff .tif .ico .mp4 .mov .m4v .webm .avi .mkv .mp3 .m4a .wav .aac .flac .pdf .ttf .otf .woff .woff2'.split())


def media_signature(header):
    return (header.startswith((b'\x89PNG\r\n\x1a\n', b'\xff\xd8\xff', b'GIF87a', b'GIF89a',
                               b'II*\x00', b'MM\x00*', b'OTTO', b'wOFF', b'wOF2'))
            or header[4:8] == b'ftyp'
            or (header[:4] == b'RIFF' and header[8:12] in {b'WEBP', b'AVI ', b'WAVE'})
            or header.lstrip().startswith(b'<svg'))


def inspect(revisions, all_refs=False):
    command = ['git', 'rev-list', '--objects', '--all'] if all_refs else ['git', 'rev-list', '--objects', *revisions]
    listing = subprocess.check_output(command, text=True).splitlines()
    entries = [line.split(' ', 1) for line in listing]
    violations = []
    largest = 0
    blobs = 0
    with subprocess.Popen(['git', 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE) as pipe:
        for entry in entries:
            oid, path = entry[0], entry[1] if len(entry) > 1 else ''
            pipe.stdin.write((oid + '\n').encode())
            pipe.stdin.flush()
            metadata = pipe.stdout.readline().split()
            if len(metadata) != 3:
                raise RuntimeError('Cannot inspect Git object: ' + oid)
            kind, size = metadata[1], int(metadata[2])
            header = pipe.stdout.read(min(size, 32))
            remaining = size - len(header)
            while remaining:
                block = pipe.stdout.read(min(remaining, 1024 * 1024))
                if not block:
                    raise RuntimeError('Incomplete Git object: ' + oid)
                remaining -= len(block)
            if pipe.stdout.read(1) != b'\n':
                raise RuntimeError('Invalid Git object framing: ' + oid)
            if kind == b'tree':
                # rev-list emits each blob once, so inspect every tree entry as well.
                # This catches historical renames and aliases sharing identical bytes.
                children = subprocess.check_output(['git', 'ls-tree', '-z', oid]).split(b'\0')
                for child in children:
                    if not child:
                        continue
                    fields, raw_name = child.split(b'\t', 1)
                    _, child_kind, child_oid = fields.split()
                    name = raw_name.decode('utf-8', errors='replace')
                    if name.casefold() == 'assets' or (child_kind == b'blob' and PurePosixPath(name).suffix.lower() in MEDIA):
                        child_path = str(PurePosixPath(path) / name) if path else name
                        violations.append((child_oid.decode(), child_path, 0, 'media path'))
                continue
            if kind != b'blob':
                continue
            blobs += 1
            largest = max(largest, size)
            resource = ('assets' in [part.casefold() for part in PurePosixPath(path).parts]
                        or PurePosixPath(path).suffix.lower() in MEDIA or media_signature(header))
            if resource or size > MAX_BYTES:
                violations.append((oid, path, size, 'media' if resource else 'oversized'))
        pipe.stdin.close()
        if pipe.wait() != 0:
            raise RuntimeError('Git object inspection failed')
    return blobs, largest, violations


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pre-push', action='store_true')
    parser.add_argument('--all', action='store_true', help='Inspect every local ref, including internal snapshots.')
    parser.add_argument('revisions', nargs='*')
    args = parser.parse_args()
    revisions = args.revisions
    if args.pre_push:
        revisions = []
        for line in sys.stdin:
            fields = line.split()
            if len(fields) != 4:
                raise ValueError('Invalid pre-push ref input')
            local_oid = fields[1]
            if set(local_oid) != {'0'}:
                revisions.append(local_oid)
        if not revisions:
            print('No object-bearing refs to push.')
            return 0
    elif not revisions and not args.all:
        revisions = ['HEAD']
    blobs, largest, violations = inspect(revisions, args.all)
    for oid, path, size, reason in violations:
        print(f'BLOCKED {reason}: {path or oid} ({size} bytes, {oid})')
    if violations:
        print('Push blocked. Keep media in ignored Assets and remove it from reachable Git history.')
        return 1
    print(f'PASS: {blobs} historical blobs; largest {largest} bytes; no media or files over {MAX_BYTES} bytes.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print('Resource verification failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
