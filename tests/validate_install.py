"""Import the addon in an isolated project and verify the debugger name migration."""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    project = Path(tempfile.mkdtemp(prefix='gdblueprints-install-'))
    # A private self-contained editor keeps user themes/settings out of this test.
    engine_dir = project/'engine'
    engine_dir.mkdir()
    engine_source = Path(args.godot).resolve()
    shutil.copy2(engine_source, engine_dir/engine_source.name)
    if engine_source.name.endswith('_console.exe'):
        gui = engine_source.with_name(engine_source.name.replace('_console.exe', '.exe'))
        shutil.copy2(gui, engine_dir/gui.name)
    (engine_dir/'_sc_').touch()
    (engine_dir/'.gdignore').touch()
    addon = project/'addons'/'GDBlueprints'
    shutil.copytree(source, addon, ignore=shutil.ignore_patterns('.git', '__pycache__', '.agents', '.codex'))
    (project/'project.godot').write_text('''config_version=5

[application]
config/name="GDBlueprints installation validation"

[autoload]
BlueprintsForGodotDebugger="*res://addons/GDBlueprints/gdblueprints_debugger.gd"
LogicBricksDebugger="*res://addons/GDBlueprints/gdblueprints_debugger.gd"

[editor_plugins]
enabled=PackedStringArray("res://addons/GDBlueprints/plugin.cfg")

[rendering]
renderer/rendering_method="gl_compatibility"
''', encoding='utf-8')
    result = subprocess.run([str(engine_dir/engine_source.name), '--headless', '--path', str(project), '--editor', '--import', '--quit', '--log-file', str(project/'import.log')], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=120)
    output = result.stdout + result.stderr
    config = (project/'project.godot').read_text(encoding='utf-8')
    assert result.returncode == 0 and 'SCRIPT ERROR:' not in output and '\nERROR:' not in output, output
    assert 'GDBlueprintsDebugger=' in config, config
    assert 'BlueprintsForGodotDebugger=' not in config and 'LogicBricksDebugger=' not in config, config
    print('Clean editor import and owned debugger migration passed.')
    print('Isolated project:', project)

if __name__ == '__main__': main()
