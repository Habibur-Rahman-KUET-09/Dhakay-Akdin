#!/usr/bin/env python3
"""Checks the game's text and numbers before they reach a phone.

    python3 tool/validate_content.py

- balance.json: every number non-negative, every [low, high] pair in order,
  passenger weights present.
- Strings (app/lib/l10n/*.arb, and any {"bn": ..., "en": ...} text in
  app/assets/content): the same keys and placeholders in both languages, and
  only characters the bundled font (Hind Siliguri) can draw. It has no
  arrows (→), check marks or stars (★): use an icon for those, or the
  placeholder box shows on the phone.
- maps/*.json: rows of equal length, only legend characters, one home (H),
  a border of buildings. Whether every road can be reached legally is
  checked by the app's tests (test/rickshaw/road_test.dart).
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app'))
FONT = os.path.join(ROOT, 'assets', 'fonts', 'HindSiliguri-Regular.ttf')
errors = []


def err(where, msg):
    errors.append(f'{where}: {msg}')


def check_balance():
    path = os.path.join(ROOT, 'assets', 'content', 'balance.json')
    b = json.load(open(path, encoding='utf-8'))
    for section in ('economy', 'unlocks', 'tara', 'ads', 'rickshaw', 'bus', 'tea_stall', 'fund_projects'):
        if section not in b:
            err('balance.json', f'missing section {section}')

    def walk(v, where):
        if isinstance(v, dict):
            for k, x in v.items():
                walk(x, f'{where}.{k}' if where else k)
        elif isinstance(v, list):
            if len(v) == 2 and all(isinstance(x, (int, float)) for x in v) and v[0] > v[1] and not where.endswith('streak'):
                err('balance.json', f'{where}: range {v} is backwards')
            for x in v:
                walk(x, where)
        elif isinstance(v, (int, float)) and not isinstance(v, bool) and v < 0:
            err('balance.json', f'{where}: negative number {v}')

    walk(b, '')
    weights = sum(p.get('weight', 0) for p in b.get('rickshaw', {}).get('passengers', {}).values())
    if weights <= 0:
        err('balance.json', 'rickshaw.passengers need weights above 0')
    for name, item in b.get('tea_stall', {}).get('menu', {}).items():
        if not item.get('steps'):
            err('balance.json', f'tea_stall.menu.{name} has no steps')


def placeholders(s):
    return set(re.findall(r'\{(\w+)', s))


def check_arb():
    files = {os.path.basename(p)[4:-4]: json.load(open(p, encoding='utf-8')) for p in glob.glob(os.path.join(ROOT, 'lib', 'l10n', 'app_*.arb'))}
    bn, en = files.get('bn', {}), files.get('en', {})
    keys = lambda d: {k for k in d if not k.startswith('@')}
    for k in sorted(keys(en) ^ keys(bn)):
        err('l10n', f'"{k}" is in only one language')
    for k in sorted(keys(en) & keys(bn)):
        if placeholders(en[k]) != placeholders(bn[k]):
            err('l10n', f'"{k}" has different placeholders in Bangla and English')
    return [(f'l10n {lang}.{k}', v) for lang, d in files.items() for k, v in d.items() if not k.startswith('@') and isinstance(v, str)]


def content_texts():
    out = []
    for path in glob.glob(os.path.join(ROOT, 'assets', 'content', '**', '*.json'), recursive=True):
        rel = os.path.relpath(path, ROOT)

        def walk(v, where):
            if isinstance(v, dict):
                if set(v) == {'bn', 'en'}:
                    for lang in ('bn', 'en'):
                        texts = v[lang] if isinstance(v[lang], list) else [v[lang]]
                        if not all(isinstance(t, str) and t.strip() for t in texts):
                            err(rel, f'{where}: {lang} text missing')
                        out.extend((f'{rel} {where}.{lang}', t) for t in texts if isinstance(t, str))
                    return
                for k, x in v.items():
                    walk(x, f'{where}.{k}')
            elif isinstance(v, list):
                for i, x in enumerate(v):
                    walk(x, f'{where}[{i}]')

        walk(json.load(open(path, encoding='utf-8')), '')
    return out


def check_glyphs(texts):
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        print('fonttools not installed (pip install fonttools); glyph check skipped')
        return
    cmap = TTFont(FONT).getBestCmap()
    # Zero-width joiners shape conjuncts such as র‍্য; the font handles them.
    allowed = {0x200C, 0x200D, 0x0A}
    for where, text in texts:
        missing = sorted({c for c in text if ord(c) not in cmap and ord(c) not in allowed})
        if missing:
            err(where, f'the font cannot draw {" ".join(missing)} (use an icon instead)')


MAP_TILES = set('#.nesw' + 'WTPH')


def check_maps():
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets', 'content', 'maps', '*.json'))):
        rel = os.path.relpath(path, ROOT)
        m = json.load(open(path, encoding='utf-8'))
        rows = m.get('rows') or []
        if not rows:
            err(rel, 'no rows')
            continue
        if len({len(r) for r in rows}) != 1:
            err(rel, 'rows have different lengths')
        for y, r in enumerate(rows):
            bad = set(r) - MAP_TILES
            if bad:
                err(rel, f'row {y}: unknown tiles {" ".join(sorted(bad))}')
        if sum(r.count('H') for r in rows) != 1:
            err(rel, 'needs exactly one home tile (H)')
        edge = rows[0] + rows[-1] + ''.join(r[0] + r[-1] for r in rows)
        if set(edge) != {'#'}:
            err(rel, 'the edge must be all buildings (#)')


def main():
    check_balance()
    check_maps()
    texts = check_arb() + content_texts()
    check_glyphs(texts)
    if errors:
        print('\n'.join(errors))
        sys.exit(1)
    print(f'content OK ({len(texts)} texts checked)')


if __name__ == '__main__':
    main()
