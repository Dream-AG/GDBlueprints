"""Validate the canonical addon using isolated projects, real exports and package imports."""
from pathlib import Path
import argparse
import json
import platform
import re
import shutil
import subprocess
import sys
import tempfile

ADDON = Path(__file__).resolve().parents[1]
CASES = {
    'validate_sources': r'Source validation: \d+ scripts, 0 failures\.',
    'validate_addon': r'GDBlueprints validator: checked 172 registered nodes\.',
    'regression_0472': r'0\.4\.7\.2 regressions: 0 failures',
    'script_interop': r'Script interoperability: 0 failures\.',
    'node_extension': r'Node extension failures: 0',
    'node_behavior_regressions': r'Node behavior regressions: \[\]',
    'execution_flow': r'Execution flow failures: \[\]',
    'milestone1_execution': r'Milestone 1 runtime failures: \[\]',
    'milestone1_editor': r'Milestone 1 editor failures: \[\]',
    'typed_data': r'Typed data regressions passed\.',
    'event_parameters': r'Event parameter failures: \[\]',
    'graph_functions': r'Graph function failures: \[\]',
    'milestone2_types': r'Milestone 2 type failures: \[\]',
    'milestone3_interop': r'Milestone 3 interoperability failures: \[\]',
    'milestone4_debugger': r'Milestone 4 debugger failures: \[\]',
    'milestone5_gameplay': r'Milestone 5 gameplay failures: \[\]',
    'milestone6_persistence': r'Milestone 6 persistence/project-scale failures: \[\]',
    'resource_node_runtime': r'Resource node runtime: \d+ assertions; failures: \[\]',
    'compiler_maintenance': r'Compiler maintenance failures: \[\]',
    'audit_node_modes': r'Node mode audit: \d+ parsed, 0 failed,',
    'export_node_catalog': r'Exported 172 node definitions\.',
    'documentation_links': r'Documentation link failures: \[\]',
}
PROJECT = '''config_version=5
[application]
config/name="GDBlueprints validation"
run/main_scene="res://addons/GDBlueprints/examples/gameplay/game_2d.tscn"
[autoload]
GlobalVars="*res://addons/GDBlueprints/global_vars.gd"
GDBlueprintsDebugger="*res://addons/GDBlueprints/gdblueprints_debugger.gd"
[editor_plugins]
enabled=PackedStringArray("res://addons/GDBlueprints/plugin.cfg")
[rendering]
renderer/rendering_method="gl_compatibility"
'''

def run(command, log, marker=None, timeout=240):
    result = subprocess.run([str(x) for x in command], capture_output=True, text=True,
                            encoding='utf-8', errors='replace', timeout=timeout)
    output = result.stdout + result.stderr
    log.write_text(output, encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR:' in output or 'ObjectDB instances were leaked' in output or (marker and not re.search(marker, output)):
        raise RuntimeError(f'{log.name} failed:\n{output[-10000:]}')
    print('PASS ' + log.stem, flush=True)


def private_engine(godot, directory):
    directory.mkdir()
    engine = Path(godot).resolve()
    shutil.copy2(engine, directory / engine.name)
    if engine.name.endswith('_console.exe'):
        gui = engine.with_name(engine.name.replace('_console.exe', '.exe'))
        shutil.copy2(gui, directory / gui.name)
    (directory / '_sc_').touch()
    (directory / '.gdignore').touch()
    return directory / engine.name


def make_project(project):
    shutil.copytree(ADDON, project / 'addons/GDBlueprints', ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '.git', '.godot'))
    from package_release import empty_globals
    (project / 'addons/GDBlueprints/global_vars.gd').write_bytes(empty_globals())
    (project / 'project.godot').write_text(PROJECT, encoding='utf-8')


def import_project(engine, project, logs, label):
    run([engine, '--headless', '--path', project, '--editor', '--import', '--quit', '--log-file', logs / f'{label}-engine.log'], logs / f'{label}.log')


def regressions(args, logs):
    with tempfile.TemporaryDirectory(prefix='gdblueprints-regressions-') as temp:
        project = Path(temp)
        engine = private_engine(args.godot, project / 'engine')
        make_project(project)
        import_project(engine, project, logs, 'import')
        for case, marker in CASES.items():
            run([engine, '--headless', '--path', project, '--script', f'res://addons/GDBlueprints/tests/{case}.gd', '--log-file', logs / f'{case}-engine.log'], logs / f'{case}.log', marker)
        docs = project / 'addons/GDBlueprints/documentation'
        for name in ('build_site', 'validate_site'):
            run([sys.executable, '-X', 'utf8', docs / f'tools/{name}.py'], logs / f'{name}.log')
        run([args.node, project / 'addons/GDBlueprints/tests/documentation_theme.cjs'], logs / 'theme.log')


def exports(args, logs):
    system = platform.system()
    if system not in ('Windows', 'Linux'): raise RuntimeError('Native export validation currently supports Windows/Linux.')
    templates = Path(args.templates).resolve()
    names = {mode: ('windows_' + mode + '_x86_64.exe' if system == 'Windows' else 'linux_' + mode + '.x86_64') for mode in ('debug', 'release')}
    for name in names.values():
        if not (templates / name).is_file(): raise RuntimeError('Missing template: ' + name)
    with tempfile.TemporaryDirectory(prefix='gdblueprints-exports-') as temp:
        project = Path(temp)
        engine = private_engine(args.godot, project / 'engine')
        make_project(project)
        (project / 'project.godot').write_text(PROJECT.replace('res://addons/GDBlueprints/examples/gameplay/game_2d.tscn', 'res://smoke.tscn'), encoding='utf-8')
        (project / 'smoke.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://addons/GDBlueprints/tests/export_smoke.gd" id="1"]\n[node name="Smoke" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
        target = 'Windows Desktop' if system == 'Windows' else 'Linux'
        preset = f'[preset.0]\nname="Native"\nplatform="{target}"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="addons/GDBlueprints/documentation/*"\nscript_export_mode=2\n[preset.0.options]\nbinary_format/architecture="x86_64"\nbinary_format/embed_pck=false\n'
        for mode, name in names.items(): preset += f'custom_template/{mode}="{(templates/name).as_posix()}"\n'
        (project / 'export_presets.cfg').write_text(preset, encoding='utf-8')
        import_project(engine, project, logs, 'export-import')
        output = project / 'build'
        output.mkdir()
        (output / '.gdignore').touch()
        for mode in names:
            binary = output / (mode + ('.exe' if system == 'Windows' else '.x86_64'))
            run([engine, '--headless', '--path', project, '--export-' + mode, 'Native', binary, '--log-file', logs / f'export-{mode}-engine.log'], logs / f'export-{mode}.log', timeout=300)
            if system == 'Linux': binary.chmod(0o755)
            display = ['--rendering-method', 'gl_compatibility'] if args.render else ['--headless']
            run([binary, '--verbose', '--log-file', logs / f'runtime-{mode}-engine.log'] + display,
                logs / f'runtime-{mode}.log', rf'Export smoke failures: \[\]; debug={str(mode == "debug").lower()}')


def packages(args, logs):
    import hashlib
    import zipfile
    from package_release import build
    with tempfile.TemporaryDirectory(prefix='gdblueprints-packages-') as temp:
        output = Path(temp)
        manifest = build(output)
        first = (output / 'SHA256SUMS.txt').read_bytes()
        build(output)
        assert first == (output / 'SHA256SUMS.txt').read_bytes(), 'Archives are not reproducible'
        for entry in manifest['archives']:
            archive = output / entry['file']
            assert hashlib.sha256(archive.read_bytes()).hexdigest() == entry['sha256']
            with tempfile.TemporaryDirectory(prefix='gdblueprints-package-import-') as unpack:
                project = Path(unpack)
                with zipfile.ZipFile(archive) as z:
                    assert len(z.namelist()) == len(set(z.namelist()))
                    for name in z.namelist():
                        assert not Path(name).is_absolute() and '..' not in Path(name).parts and '\\' not in name
                        assert hashlib.sha256(z.read(name)).hexdigest() == manifest['source_files'][name]
                    z.extractall(project)
                if not (project / 'project.godot').exists(): (project / 'project.godot').write_text(PROJECT, encoding='utf-8')
                engine = private_engine(args.godot, project / 'engine')
                label = 'package-addon' if '-addon.zip' in entry['file'] else 'package-source'
                import_project(engine, project, logs, label)
                run([engine, '--headless', '--path', project, '--script', 'res://addons/GDBlueprints/tests/validate_addon.gd', '--log-file', logs / f'{label}-registry-engine.log'], logs / f'{label}-registry.log', CASES['validate_addon'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--node', default='node')
    parser.add_argument('--templates', help='Directory containing native debug/release export templates')
    parser.add_argument('--checks', choices=['all', 'regressions', 'exports', 'packages'], default='all')
    parser.add_argument('--logs', type=Path)
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args()
    if args.checks in ('all', 'exports') and not args.templates: parser.error('--templates is required for real export tests')
    logs = args.logs.resolve() if args.logs else Path(tempfile.mkdtemp(prefix='gdblueprints-validation-'))
    logs.mkdir(parents=True, exist_ok=True)
    print('Validation logs: ' + str(logs), flush=True)
    for name, check in [('regressions', regressions), ('exports', exports), ('packages', packages)]:
        if args.checks in ('all', name): check(args, logs)
    (logs / 'summary.json').write_text(json.dumps({'status':'passed', 'checks':args.checks, 'platform':platform.platform()}, indent=2), encoding='utf-8')
    print('Requested release checks passed.')

if __name__ == '__main__': main()
