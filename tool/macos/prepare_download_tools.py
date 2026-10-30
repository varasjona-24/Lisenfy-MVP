#!/usr/bin/env python3
"""Prepare pinned standalone yt-dlp and relocate the local FFmpeg/Deno tools.
No system installation is modified. Output is ignored by git.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.desktop-tools' / 'macos'
VERSION = '2026.10.26'
SHA256 = '20d98fa608998eff87d1d35a6e9fb65e4b874639a6cc89addc19da3becde3ef1'

def run(*args):
    return subprocess.check_output(args, text=True).strip()

def main():
    if sys.platform != 'darwin':
        raise SystemExit('This preparation tool requires macOS.')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    archive = OUTPUT.parent / f'yt-dlp-{VERSION}.zip'
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        print(f'Downloading official yt-dlp {VERSION}...', flush=True)
        with urllib.request.urlopen(f'https://github.com/yt-dlp/yt-dlp/releases/download/{VERSION}/yt-dlp_macos.zip', timeout=60) as response:
            with archive.open('wb') as target:
                shutil.copyfileobj(response, target)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise SystemExit('yt-dlp checksum mismatch; refusing to execute or package it.')
    yt_root = OUTPUT / 'yt-dlp'
    if not yt_root.exists():
        yt_root.mkdir()
        subprocess.check_call(['/usr/bin/ditto', '-x', '-k', str(archive), str(yt_root)])
    # The upstream archive duplicates framework aliases as directories/files.
    # Restore the conventional layout so codesign can identify the framework.
    for framework in yt_root.rglob('*.framework'):
        versions = framework / 'Versions'
        if not versions.is_dir():
            continue
        version_names = sorted(entry.name for entry in versions.iterdir() if entry.is_dir() and entry.name != 'Current')
        if not version_names:
            continue
        aliases = [(versions / 'Current', version_names[-1]),
                   (framework / framework.stem, 'Versions/Current/' + framework.stem),
                   (framework / 'Resources', 'Versions/Current/Resources')]
        for alias, destination in aliases:
            if alias.is_symlink():
                continue
            if alias.is_dir():
                shutil.rmtree(alias)
            elif alias.exists():
                alias.unlink()
            alias.symlink_to(destination)
    bin_dir = OUTPUT / 'bin'
    lib_dir = OUTPUT / 'lib'
    bin_dir.mkdir(exist_ok=True)
    lib_dir.mkdir(exist_ok=True)
    relocated = {}

    def copy_binary(original, target):
        original = Path(original).resolve()
        if original in relocated:
            return relocated[original]
        shutil.copy2(original, target)
        target.chmod(0o755)
        relocated[original] = target
        for line in run('/usr/bin/otool', '-L', str(original)).splitlines()[1:]:
            dependency = line.strip().split(' (', 1)[0]
            if dependency.startswith(('/System/', '/usr/lib/')):
                continue
            if not dependency.startswith('/'):
                raise RuntimeError(f'Unsupported unresolved dependency {dependency} in {original}')
            dependency_path = Path(dependency).resolve()
            # A dylib's install name refers to itself.
            if dependency_path == original:
                continue
            name = hashlib.sha256(str(dependency_path).encode()).hexdigest()[:10] + '-' + dependency_path.name
            bundled = copy_binary(dependency_path, lib_dir / name)
            relative = os.path.relpath(bundled, target.parent)
            subprocess.check_call(['/usr/bin/install_name_tool', '-change', dependency, '@loader_path/' + relative, str(target)], stdout=subprocess.DEVNULL)
        if target.suffix in ('.dylib', '.so'):
            subprocess.check_call(['/usr/bin/install_name_tool', '-id', '@loader_path/' + target.name, str(target)], stdout=subprocess.DEVNULL)
        return target

    for name in ('ffmpeg', 'ffprobe', 'deno'):
        source = shutil.which(name)
        if not source:
            raise SystemExit(f'Missing {name}; install the build-time tool before preparing the bundle.')
        copy_binary(source, bin_dir / name)
    # Preserve dependency licenses supplied by Homebrew for redistribution review.
    licenses = OUTPUT / 'licenses'
    licenses.mkdir(exist_ok=True)
    for source in relocated:
        parts = source.parts
        if 'Cellar' not in parts:
            continue
        index = parts.index('Cellar')
        formula_root = Path(*parts[:index + 3])
        for pattern in ('LICENSE*', 'COPYING*', 'NOTICE*'):
            for license_file in formula_root.glob(pattern):
                if license_file.is_file():
                    shutil.copy2(license_file, licenses / f'{parts[index+1]}-{license_file.name}')
    entrypoints = list(yt_root.rglob('yt-dlp_macos'))
    if len(entrypoints) != 1:
        raise SystemExit('Unable to locate the standalone yt-dlp entrypoint.')
    tree_hash = hashlib.sha256()
    for entry in sorted(OUTPUT.rglob('*')):
        if entry.name == 'manifest.json' or not entry.is_file():
            continue
        tree_hash.update(str(entry.relative_to(OUTPUT)).encode())
        tree_hash.update(os.readlink(entry).encode() if entry.is_symlink() else entry.read_bytes())
    (OUTPUT / 'manifest.json').write_text(json.dumps({
        'ytDlpVersion': VERSION, 'ytDlpArchiveSha256': SHA256,
        'ytDlp': str(entrypoints[0].relative_to(OUTPUT)),
        'architecture': run('/usr/bin/uname', '-m'),
        'bundleSha256': tree_hash.hexdigest(),
    }, indent=2) + '\n')
    print(f'Prepared tools: {OUTPUT}', flush=True)

if __name__ == '__main__':
    main()
