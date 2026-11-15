#!/usr/bin/env python3
"""Builds lib/l10n/app_<lang>.arb from the compact source tool/i18n/strings/*.txt.

Line format:   key | French text | English text
- Blank lines and lines starting with '#' are ignored.
- Placeholders: {name}. Placeholders named n, count, or nXxx are ints (plural-ready);
  everything else is a String.
- ICU plurals/selects are allowed: {n, plural, =1{…} other{…}}.
To add a language: add a column, list it in LANGS, and run this script.
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANGS = ['fr', 'en']
entries = {}
order = []
for path in sorted(glob.glob(os.path.join(ROOT, 'tool/i18n/strings/*.txt'))):
    for i, line in enumerate(open(path, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        parts = [p.strip() for p in line.split(' | ')]
        if len(parts) != len(LANGS) + 1:
            sys.exit(f'{path}:{i}: expected {len(LANGS)+1} columns, got {len(parts)}: {line}')
        key = parts[0]
        if not re.match(r'^[a-z][A-Za-z0-9]*$', key):
            sys.exit(f'{path}:{i}: bad key {key!r}')
        if key in entries:
            sys.exit(f'{path}:{i}: duplicate key {key}')
        entries[key] = [p.replace('\\n', '\n') for p in parts[1:]]
        order.append(key)

def top_placeholders(text):
    """Top-level {name} or {name, plural|select, ...} placeholders."""
    names, depth, i = [], 0, 0
    while i < len(text):
        c = text[i]
        if c == '{':
            if depth == 0:
                m = re.match(r'\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(,|\})', text[i:])
                if m and m.group(1) not in names:
                    names.append(m.group(1))
            depth += 1
        elif c == '}':
            depth -= 1
        i += 1
    return names

def is_int(name):
    return name in ('n', 'count') or re.match(r'^n[A-Z]', name) is not None

for li, lang in enumerate(LANGS):
    out = {'@@locale': lang}
    for key in order:
        text = entries[key][li]
        out[key] = text
        if li == 0:
            ph = top_placeholders(text)
            if ph:
                out['@' + key] = {'placeholders': {p: {'type': 'int' if is_int(p) else 'String'} for p in ph}}
    with open(os.path.join(ROOT, f'lib/l10n/app_{lang}.arb'), 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write('\n')
print(f'{len(order)} strings × {len(LANGS)} languages')
