"""Fetch official CI engine/templates with release SHA512 verification."""
from pathlib import Path
import hashlib
import os
import platform
import shutil
import urllib.request
import zipfile

VERSION = '4.7.2-stable'

def main():
    host = platform.system()
    if host not in ('Windows', 'Linux'): raise RuntimeError('Unsupported CI platform')
    root = Path(os.environ['RUNNER_TEMP']) / 'gdblueprints-engine'
    root.mkdir(exist_ok=True)
    url = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}/'
    data = urllib.request.urlopen(url + 'SHA512-SUMS.txt', timeout=60).read().decode()
    hashes = {line.split()[1]:line.split()[0] for line in data.splitlines() if line.strip()}
    def download(name):
        path = root / name
        urllib.request.urlretrieve(url + name, path)
        with path.open('rb') as source:
            if hashlib.file_digest(source, 'sha512').hexdigest() != hashes[name]: raise RuntimeError('Checksum mismatch: ' + name)
        return path
    stem = f'Godot_v{VERSION}_' + ('win64.exe' if host == 'Windows' else 'linux.x86_64')
    with zipfile.ZipFile(download(stem + '.zip')) as z:
        for name in z.namelist():
            if Path(name).name != name: raise RuntimeError('Unexpected engine archive path')
        z.extractall(root)
    engine = root / (stem.replace('.exe', '_console.exe') if host == 'Windows' else stem)
    engine.chmod(0o755)
    with zipfile.ZipFile(download(f'Godot_v{VERSION}_export_templates.tpz')) as z:
        for mode in ('debug', 'release'):
            name = f'windows_{mode}_x86_64.exe' if host == 'Windows' else f'linux_{mode}.x86_64'
            with z.open('templates/' + name) as source, (root/name).open('wb') as output: shutil.copyfileobj(source, output)
            (root/name).chmod(0o755)
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as environment:
        environment.write(f'GODOT={engine}\nGODOT_TEMPLATES={root}\n')
    print('Official engine and native templates verified.')

if __name__ == '__main__': main()
