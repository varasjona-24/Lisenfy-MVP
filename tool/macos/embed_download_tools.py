#!/usr/bin/env python3
"""Xcode phase: copy and sign prepared tools with the app's signing identity."""
import json
import hashlib
import os
import plistlib
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
source = Path(os.environ.get('LISTENFY_MACOS_DOWNLOAD_TOOLS_DIR', ROOT / '.desktop-tools' / 'macos'))
if not (source / 'manifest.json').exists():
    raise SystemExit('Download tools are not prepared. Run python3 tool/macos/prepare_download_tools.py before building macOS.')
manifest = json.loads((source / 'manifest.json').read_text())
architectures = os.environ.get('ARCHS', '').split()
if architectures and any(arch != manifest['architecture'] for arch in architectures):
    raise SystemExit(f'Download tools are prepared for {manifest["architecture"]}; build ARCHS={architectures}. Prepare tools for the target architecture.')
resources = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['UNLOCALIZED_RESOURCES_FOLDER_PATH']
target = resources / 'download-tools'
identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY') or '-'
stamp_source = (source / 'manifest.json').read_bytes() + Path(__file__).read_bytes() + identity.encode()
for entitlements in sorted((ROOT / 'macos' / 'Runner').glob('Download*.entitlements')):
    stamp_source += entitlements.read_bytes()
stamp = hashlib.sha256(stamp_source).hexdigest()
if (target / '.listenfy-tools.stamp').exists() and (target / '.listenfy-tools.stamp').read_text() == stamp:
    print('Signed download tools are already embedded.')
    sys.exit(0)
if target.exists():
    shutil.rmtree(target)
shutil.copytree(source, target, symlinks=True)
identity = os.environ.get('EXPANDED_CODE_SIGN_IDENTITY') or '-'
helpers = {target / manifest['ytDlp'], *(target / 'bin' / name for name in ('ffmpeg', 'ffprobe', 'deno'))}
seen = set()
# Sign nested libraries first, then executable helpers. Do not use --deep signing.
for entry in sorted(target.rglob('*'), key=lambda item: len(item.parts), reverse=True):
    if not entry.is_file() or entry.is_symlink():
        continue
    description = subprocess.check_output(['/usr/bin/file', '-b', str(entry)], text=True)
    if 'Mach-O' not in description:
        continue
    entry.chmod(entry.stat().st_mode | 0o200)
    timestamp = '--timestamp' if identity != '-' and os.environ.get('CONFIGURATION') == 'Release' else '--timestamp=none'
    command = ['/usr/bin/codesign', '--force', '--sign', identity, '--options', 'runtime', timestamp]
    if entry in helpers:
        runtime = entry.name == 'deno'
        python_runtime = entry.name == 'yt-dlp_macos'
        entitlement_name = 'DownloadRuntime.entitlements' if runtime else 'DownloadPython.entitlements' if python_runtime else 'DownloadHelper.entitlements'
        entitlements = ROOT / 'macos' / 'Runner' / entitlement_name
        if identity == '-':
            # Ad-hoc libraries have no Team ID. Scope this development-only
            # exception to helpers loading the verified bundled dependencies.
            values = plistlib.loads(entitlements.read_bytes())
            values['com.apple.security.cs.disable-library-validation'] = True
            generated = target / ('.' + entry.name + '-debug.plist')
            generated.write_bytes(plistlib.dumps(values))
            entitlements = generated
        command += ['--entitlements', str(entitlements)]
        seen.add(entry)
    command.append(str(entry))
    subprocess.check_call(command, stdout=subprocess.DEVNULL)
if helpers != seen:
    raise SystemExit(f'Missing native executable helpers: {helpers - seen}')
for framework in sorted(target.rglob('*.framework'), key=lambda item: len(item.parts), reverse=True):
    subprocess.check_call(['/usr/bin/codesign', '--force', '--sign', identity, '--options', 'runtime', timestamp, str(framework)], stdout=subprocess.DEVNULL)
for helper in helpers:
    subprocess.check_call(['/usr/bin/codesign', '--verify', '--strict', str(helper)])
print(f'Embedded signed download helpers into {target}')

(target / '.listenfy-tools.stamp').write_text(stamp)
