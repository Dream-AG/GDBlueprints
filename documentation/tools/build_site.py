#!/usr/bin/env python3
"""Build the offline GDBlueprints manual from Markdown and Godot's live inventory.

Standard library only. Run export_node_catalog.gd and audit_node_modes.gd first.
The small Markdown subset is headings, paragraphs, lists, fenced code and inline
links/emphasis. Node tables are generated directly from the registry data.
"""
from pathlib import Path
from html import escape
import json
import re

ROOT = Path(__file__).resolve().parents[1]
PAGES = {
    'index.html': ('Start here', 'START_HERE.md'),
    'user-guide.html': ('Use the graph', 'USER_GUIDE.md'),
    'references-and-scenes.html': ('Objects and signals', 'REFERENCES_AND_SCENES.md'),
    'contributing.html': ('Create nodes', 'CONTRIBUTING.md'),
    'node-api.html': ('Node API', 'NODE_DEFINITION_API.md'),
    'godot-for-unreal-users.html': ('From Unreal to Godot', 'GODOT_FOR_UNREAL_USERS.md'),
    'execution-model.html': ('Execution and loops', 'EXECUTION_MODEL.md'),
    'functions.html': ('Functions and locals', 'FUNCTIONS.md'),
    'types-and-enums.html': ('Collections and enums', 'TYPES_AND_ENUMS.md'),
    'gdscript-interop.html': ('GDScript interoperability', 'GDSCRIPT_INTEROP.md'),
    'debugging.html': ('Debug graphs', 'DEBUGGING.md'),
    'gameplay-examples.html': ('Playable examples', 'GAMEPLAY_EXAMPLES.md'),
    'persistence-and-reuse.html': ('Persistence and reuse', 'PERSISTENCE_AND_REUSE.md'),
    'maintenance.html': ('Maintenance and coverage', 'MAINTENANCE.md'),
    'release.html': ('Release and publishing', 'RELEASE.md'),
    'roadmap.html': ('Roadmap', 'ROADMAP.md'),
    'architecture.html': ('Architecture', 'ARCHITECTURE.md'),
    'testing-validation.html': ('Testing', 'TESTING_AND_VALIDATION.md'),
    'compatibility.html': ('Compatibility', 'MIGRATION_AND_COMPATIBILITY.md'),
}

def inline(value):
    value = escape(str(value))
    value = re.sub(r'`([^`]+)`', r'<code>\1</code>', value)
    value = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', value)
    return re.sub(r'\[([^]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', value)

def markdown(source):
    out, paragraph, code = [], [], None
    list_kind = None
    def flush():
        if paragraph:
            out.append('<p>' + inline(' '.join(paragraph)) + '</p>')
            paragraph.clear()
    for line in source.splitlines():
        if line.startswith('```'):
            flush()
            if code is None: code = []
            else:
                out.append('<pre><code>' + escape('\n'.join(code)) + '</code></pre>')
                code = None
            continue
        if code is not None:
            code.append(line)
            continue
        item = re.match(r'^(?:([-*]) |(\d+)\. )(.*)', line)
        kind = ('ul' if item[1] else 'ol') if item else None
        if list_kind and kind != list_kind:
            out.append('</' + list_kind + '>')
            list_kind = None
        if item:
            flush()
            if not list_kind:
                out.append('<' + kind + '>')
                list_kind = kind
            out.append('<li>' + inline(item[3]) + '</li>')
        elif line.startswith('#'):
            flush()
            level = len(line) - len(line.lstrip('#'))
            title = line[level:].strip()
            anchor = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
            out.append(f'<h{level} id="{anchor}">{inline(title)}</h{level}>')
        elif not line.strip(): flush()
        else: paragraph.append(line)
    flush()
    if list_kind: out.append('</' + list_kind + '>')
    return '\n'.join(out)

def shell(title, body, redirect=None):
    nav = ''.join(f'<a href="{url}">{escape(label)}</a>' for url, label in
                  [('index.html', 'Start'), ('user-guide.html', 'Graph guide'), ('nodes.html', 'All nodes'), ('contributing.html', 'Create nodes'), ('testing-validation.html', 'Testing')])
    redirect_tag = f'<meta http-equiv="refresh" content="0;url={escape(redirect)}">' if redirect else ''
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)} · GDBlueprints</title><script>try{{document.documentElement.dataset.theme=localStorage.getItem('gdblueprints-theme')||(matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light')}}catch(e){{document.documentElement.dataset.theme=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light'}}</script><link rel="stylesheet" href="assets/manual.css">{redirect_tag}</head>
<body><header><a class="brand" href="index.html">GDBlueprints</a><span>0.10.1 alpha</span><button id="theme-toggle" type="button" aria-label="Toggle dark mode" aria-pressed="false">Dark mode</button><nav aria-label="Documentation">{nav}</nav></header>
<main>{body}</main><footer>GDBlueprints · Visual GDScript for Godot · <a href="../THIRD_PARTY_NOTICES.md">Credits and license</a></footer>
<script src="assets/manual.js"></script></body></html>'''

def table(headers, rows):
    if not rows: return '<p>None declared.</p>'
    return '<div class="table-scroll"><table><thead><tr>' + ''.join('<th scope="col">' + escape(x) + '</th>' for x in headers) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + inline(x) + '</td>' for x in row) + '</tr>' for row in rows) + '</tbody></table></div>'

TYPES = {0:'Variant', 1:'Bool', 2:'Int', 3:'Float', 4:'String', 5:'Vector2', 6:'Vector2i', 9:'Vector3', 10:'Vector3i', 20:'Color', 21:'StringName', 22:'NodePath', 24:'Object', 27:'Dictionary', 28:'Array'}

def node_reference(nodes, audit):
    sections = ['<h1>All Blueprint nodes</h1>', f'<p>{len(nodes)} registered definitions, including compatibility nodes and domain-specific wrappers. Names and settings come from the running plugin registry. Stable IDs distinguish nodes with the same display name.</p>', '<label for="node-search">Find a node, use case, setting, or Godot API</label><input id="node-search" type="search" placeholder="Try print, physics, signal, camera…"><p id="result-count" aria-live="polite"></p>', '<p>Events start or test a chain; Flow controls execution; Actions do work; Values provide expressions. A passing parse check verifies generated syntax, not every gameplay outcome. See <a href="testing-validation.html">test coverage</a>.</p>']
    kind = {'sensor':'Event', 'controller':'Flow', 'actuator':'Action', 'value':'Value'}
    for node in sorted(nodes, key=lambda x: (x['name'].lower(), x['class'])):
        node_id = node['class']
        status = [c for c in audit.get('cases', []) if c['id'] == node_id]
        passed = sum(c['status'] == 'parse passed' for c in status)
        failed = sum(c['status'] == 'parse failed' for c in status)
        desc = node['description'].replace('\\n', '\n')
        if not desc: raise ValueError('Missing description: ' + node_id)
        section = [f'<article class="node" id="{escape(node_id)}"><h2>{escape(node["name"])} <a class="permalink" href="#{escape(node_id)}" aria-label="Link to this node">#</a></h2>', f'<p class="meta">{kind[node["type"]]} · {escape(node["domain"])} · {escape(node["category"] or "General")} · <code>{escape(node_id)}</code></p>', '<p>' + inline(desc).replace('\n', '<br>') + '</p>']
        if node['godot_term']: section.append('<p><strong>Godot equivalent:</strong> ' + inline(node['godot_term']) + '</p>')
        if node['hidden_menu']: section.append('<p class="notice">Compatibility definition: retained for saved graphs; hidden from the add-node menu.</p>')
        if node['aliases']: section.append('<p><strong>Search terms:</strong> ' + inline(', '.join(node['aliases'])) + '</p>')
        section.append('<h3>Settings and inputs</h3>')
        rows = []
        for prop in node['inputs']:
            name = prop.get('name', '')
            tip = prop.get('tooltip') or node['tooltips'].get(name, '')
            if prop.get('required'): tip += ' Required' + (' when ' + str(prop['required_if']) if prop.get('required_if') else '') + '.'
            if prop.get('visible_if'): tip += ' Visible when ' + str(prop['visible_if']) + '.'
            if prop.get('hint_string'): tip += ' Options/hint: ' + str(prop['hint_string']) + '.'
            value = node.get('defaults', {}).get(name, prop.get('default', ''))
            rows.append([name, str(prop.get('pin_type', TYPES.get(prop.get('type'), prop.get('type', 'Variant')))), str(value), tip.replace('\\n', ' ')])
        section.append(table(['Setting', 'Type', 'Default', 'Use / requirements'], rows))
        section.append('<h3>Outputs</h3>' + table(['Name', 'Type', 'Expression'], [[o.get('name', ''), o.get('type','Variant'), o.get('expression','')] for o in node['outputs']]))
        section.append('<p><strong>Execution:</strong> ' + inline(', '.join(x.get('name','') for x in node.get('exec_inputs',[])) or 'no incoming execution') + ' → ' + inline(', '.join(x.get('name','') for x in node.get('exec_outputs',[])) or 'no execution output') + '.</p>')
        restrictions = {v for v in node.get('compatibility', {}).values() if v}
        if restrictions: section.append('<p><strong>Target requirements:</strong> ' + inline(' '.join(sorted(restrictions))) + '</p>')
        for warning in node.get('configuration_warnings', []): section.append('<p class="notice">Setup: ' + inline(warning) + '</p>')
        section.append(f'<p class="meta">Audit: {passed} generated-code cases passed; {failed} failed; {len(status)-passed-failed} need configuration or scene fixtures. Runtime coverage varies by node.</p>')
        source_path = '../' + node['script_path'].split('GDBlueprints/',1)[1]
        section.append(f'<p><a href="{escape(source_path)}">Read node implementation</a></p></article>')
        sections.extend(section)
    return '\n'.join(sections)

def build():
    nodes = json.loads((ROOT/'addon_inventory.json').read_text(encoding='utf-8'))
    audit = json.loads((ROOT/'node_audit.json').read_text(encoding='utf-8'))
    for url, (title, source) in PAGES.items():
        (ROOT/url).write_text(shell(title, markdown((ROOT/'guides'/source).read_text(encoding='utf-8'))), encoding='utf-8')
    (ROOT/'nodes.html').write_text(shell('All nodes', node_reference(nodes, audit)), encoding='utf-8')
    # Replace old manuals with small redirects; do not leave outdated instructions searchable.
    for old in ROOT.glob('*.html'):
        if old.name in PAGES or old.name == 'nodes.html': continue
        target = 'nodes.html' if any(x in old.stem for x in ['sensor','actuator','controller','brick-reference']) else 'user-guide.html'
        old.write_text(shell('Documentation moved', f'<h1>Documentation moved</h1><p><a href="{target}">Open the current GDBlueprints manual</a>.</p>', target), encoding='utf-8')
    (ROOT/'NODE_INDEX.md').write_text('# GDBlueprints node index\n\nGenerated from the live registry. Open nodes.html for settings, outputs and validation coverage.\n\n' + '\n'.join(f'- [{n["name"]} ({n["class"]})](nodes.html#{n["class"]}): ' + n['description'].replace('\n', ' ').replace('\\n',' ') for n in sorted(nodes,key=lambda x:x['name'].lower())) + '\n', encoding='utf-8')
    print(f'Built GDBlueprints manual and {len(nodes)} node sections.')

if __name__ == '__main__': build()
