"""Build deterministic public archives from the one installed addon; globals are sanitized in memory."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import zipfile

ADDON = Path(__file__).resolve().parents[1]
EXCLUDED = {'.git', '.godot', '__pycache__', '.agents', '.codex', 'dist', 'test-results'}

def empty_globals():
    body = '# No project globals declared.'
    return ('extends Node\n\n# === GDBLUEPRINTS GLOBALS START ===\n# GDBlueprints generated SHA256: ' + hashlib.sha256(body.encode()).hexdigest() + '\n' + body + '\n# === GDBLUEPRINTS GLOBALS END ===\n').encode()

def build(output):
    output = Path(output).resolve()
    if output == ADDON or ADDON in output.parents: raise ValueError('Write release artifacts outside the addon.')
    output.mkdir(parents=True, exist_ok=True)
    files = {}
    for path in sorted(ADDON.rglob('*')):
        relative = path.relative_to(ADDON)
        if not path.is_file() or any(part in EXCLUDED for part in relative.parts): continue
        if path.suffix in ('.pyc', '.log', '.tmp') or path.name == 'export_credentials.cfg' or path.name.startswith('.env'): continue
        if path.is_symlink(): raise ValueError('Refusing symlink: ' + str(relative))
        files['addons/GDBlueprints/' + relative.as_posix()] = empty_globals() if relative.as_posix() == 'global_vars.gd' else path.read_bytes()
    from validate_release import PROJECT
    for name in ('LICENSE', 'THIRD_PARTY_NOTICES.md', 'CHANGELOG.md'):
        files[name] = (ADDON / name).read_bytes()
    files['project.godot'] = PROJECT.replace('GDBlueprints validation', 'GDBlueprints examples').encode()
    readme = (ADDON / 'README.md').read_text(encoding='utf-8').replace('](documentation/', '](addons/GDBlueprints/documentation/').replace('](tools/', '](addons/GDBlueprints/tools/')
    readme += '\n## Source checkout\n\nImport project.godot to run the examples. Development and release tools are in addons/GDBlueprints/tools. See its RELEASE_TOOLS.md.\n'
    files['README.md'] = readme.encode()
    files['CONTRIBUTING.md'] = b'# Contributing\n\nSee [the node tutorial](addons/GDBlueprints/documentation/guides/CONTRIBUTING.md) and [release tooling](addons/GDBlueprints/tools/RELEASE_TOOLS.md).\n'
    files['.gitignore'] = b'.godot/\n__pycache__/\n*.pyc\n*.log\n*.tmp\n/dist/\n/test-results/\nexport_credentials.cfg\n.env\n.env.*\n'
    files['.gitattributes'] = b'* text=auto eol=lf\n/** export-ignore\n/addons !export-ignore\n/addons/** !export-ignore\n'
    workflow = ADDON / 'tools/release-workflow.yml'
    if workflow.exists(): files['.github/workflows/validate.yml'] = workflow.read_bytes()
    version = re.search(r'^version="([a-zA-Z0-9.\-]+)"$', (ADDON / 'plugin.cfg').read_text(), re.M)[1]
    archives = []
    for kind in ('addon', 'source'):
        path = output / f'GDBlueprints-{version}-{kind}.zip'
        selected = {name:data for name,data in files.items() if kind == 'source' or name.startswith('addons/')}
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for name,data in sorted(selected.items()):
                info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                z.writestr(info, data)
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None and len(z.namelist()) == len(selected)
            for name,data in selected.items(): assert z.read(name) == data
        archives.append({'file':path.name, 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'files':len(selected)})
    manifest = {'version':version, 'archives':archives, 'source_files':{name:hashlib.sha256(data).hexdigest() for name,data in files.items()}}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{item["sha256"]}  {item["file"]}\n' for item in archives), encoding='utf-8')
    print('Verified release archives: ' + str(output), flush=True)
    return manifest

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    build(parser.parse_args().output)
