#!/usr/bin/env python3
"""Validate every local manual link, anchor, registry node, and branding string."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
import json
import re

ROOT = Path(__file__).resolve().parents[1]

class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.ids, self.links = [], []
        self.feed(text)
    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if 'id' in values: self.ids.append(values['id'])
        for key in ['href', 'src']:
            if key in values: self.links.append(values[key])

def main():
    errors = []
    pages = {p.resolve(): Page(p.read_text(encoding='utf-8')) for p in ROOT.glob('*.html')}
    for path, page in pages.items():
        if len(page.ids) != len(set(page.ids)): errors.append(f'{path.name}: duplicate anchors')
        if re.search(r'BlueprintsForGodot|Blueprints for Godot|Logic Bricks|\bGates\b', path.read_text(encoding='utf-8'), re.I):
            errors.append(f'{path.name}: obsolete branding or navigation')
        for value in page.links:
            parsed = urlsplit(value)
            if parsed.scheme or parsed.netloc: continue
            target = (path.parent/unquote(parsed.path)).resolve() if parsed.path else path
            if not target.exists(): errors.append(f'{path.name}: missing {value}')
            if parsed.fragment and target in pages and unquote(parsed.fragment) not in pages[target].ids:
                errors.append(f'{path.name}: missing anchor {value}')
    inventory = json.loads((ROOT/'addon_inventory.json').read_text(encoding='utf-8'))
    reference = pages[(ROOT/'nodes.html').resolve()]
    for node in inventory:
        if node['class'] not in reference.ids: errors.append('Missing node help: ' + node['class'])
        if not node['description'].strip(): errors.append('Missing use case: ' + node['class'])
    if errors: raise SystemExit('\n'.join(errors))
    print(f'Validated {len(pages)} pages, all local links and anchors, and {len(inventory)} exact node sections.')

if __name__ == '__main__': main()
