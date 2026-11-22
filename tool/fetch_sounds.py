#!/usr/bin/env python3
"""Fetches real street recordings from Freesound to stand in for the
made-up sounds of tool/make_sounds.py, into game/sounds/real/<name>.ogg.

    FREESOUND_API_KEY=... python3 tool/fetch_sounds.py [--again]

For each sound below, Freesound is searched (free licences only: CC0 or
CC-BY, never non-commercial) and the most downloaded match of the right
length is taken, unless a recording's id is pinned. The preview is cut,
made mono, faded and evened out in loudness with ffmpeg. Who made each
one and its licence go to game/sounds/real/credits.json, which the game
shows. Sounds already fetched are kept unless --again. Without a key it
does nothing, and the game keeps its made-up sounds.
"""
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'game', 'sounds', 'real')
API = 'https://freesound.org/apiv2/search/text/'
LICENCES = '("Creative Commons 0" OR "Attribution")'

# name: what to search for (tried in turn), the length to look for in
# seconds, how much to keep, and a pinned Freesound id (0: search).
PICKS = {
    'hum': {'q': ['dhaka traffic', 'bangladesh street traffic', 'india street traffic horns'], 'len': (20, 600), 'keep': 40, 'id': 0},
    'crowd': {'q': ['dhaka market', 'bangladesh market crowd', 'india market crowd'], 'len': (20, 600), 'keep': 40, 'id': 0},
    'rain': {'q': ['rain on street', 'heavy rain city'], 'len': (15, 600), 'keep': 30, 'id': 0},
    'bus_inside': {'q': ['bus interior india', 'inside bus driving'], 'len': (20, 600), 'keep': 40, 'id': 0},
    'bell': {'q': ['rickshaw bell', 'bicycle bell ring'], 'len': (0.3, 4), 'keep': 3, 'id': 0},
    'horn_cng': {'q': ['auto rickshaw horn', 'tuk tuk horn'], 'len': (0.2, 4), 'keep': 2, 'id': 0},
    'horn_bus': {'q': ['bus horn', 'truck horn'], 'len': (0.3, 4), 'keep': 2.5, 'id': 0},
    'whistle': {'q': ['police whistle', 'referee whistle'], 'len': (0.3, 4), 'keep': 2.5, 'id': 0},
    'coin': {'q': ['coins drop', 'coins hand'], 'len': (0.2, 3), 'keep': 1.5, 'id': 0},
    'cup': {'q': ['tea cup clink', 'glass clink'], 'len': (0.1, 3), 'keep': 1.5, 'id': 0},
    'thump': {'q': ['hit metal panel', 'knock metal door'], 'len': (0.1, 2), 'keep': 1, 'id': 0},
}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'praner-dhaka-sounds'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def find(key, pick):
    fields = 'id,name,username,license,duration,previews,url,num_downloads'
    if pick['id']:
        url = f"https://freesound.org/apiv2/sounds/{pick['id']}/?" + urllib.parse.urlencode({'fields': fields, 'token': key})
        return json.loads(get(url))
    lo, hi = pick['len']
    for q in pick['q']:
        url = API + '?' + urllib.parse.urlencode({
            'query': q, 'filter': f'license:{LICENCES} duration:[{lo} TO {hi}]',
            'sort': 'downloads_desc', 'fields': fields, 'page_size': 5, 'token': key})
        results = json.loads(get(url)).get('results', [])
        if results:
            return results[0]
    return None


def shape(src, dst, keep):
    """Cut to `keep` seconds, mono, gentle fades, even loudness."""
    long = keep >= 10
    fades = f'afade=t=in:d=0.5,afade=t=out:st={keep - 1.5}:d=1.5,' if long else ''
    trim = '' if long else 'silenceremove=start_periods=1:start_threshold=-45dB,'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-t', str(keep), '-ac', '1', '-ar', '32000',
                    '-af', f'{trim}{fades}loudnorm=I={-20 if long else -16}:TP=-1.5',
                    '-c:a', 'libvorbis', '-q:a', '3', dst], check=True)


def main():
    key = os.environ.get('FREESOUND_API_KEY', '')
    if not key:
        print('::notice title=Street sounds::no FREESOUND_API_KEY secret, nothing fetched')
        return
    again = '--again' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    credits_path = os.path.join(OUT, 'credits.json')
    credits = json.load(open(credits_path, encoding='utf-8')) if os.path.exists(credits_path) else {}
    for name, pick in PICKS.items():
        dst = os.path.join(OUT, f'{name}.ogg')
        if os.path.exists(dst) and not again and (not pick['id'] or credits.get(name, {}).get('id') == pick['id']):
            continue
        s = find(key, pick)
        if s is None:
            print(f'::warning title=Street sounds::{name}: nothing found, keeping the made-up one')
            continue
        with tempfile.TemporaryDirectory() as tmp:
            src = os.path.join(tmp, 'preview.ogg')
            open(src, 'wb').write(get(s['previews']['preview-hq-ogg']))
            shape(src, dst, min(pick['keep'], float(s['duration'])))
        credits[name] = {'id': s['id'], 'title': s['name'], 'by': s['username'], 'licence': s['license'], 'url': s['url']}
        print(f"::notice title=Street sounds::{name}: \"{s['name']}\" by {s['username']} ({s['url']})")
    with open(credits_path, 'w', encoding='utf-8') as f:
        json.dump(credits, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write('\n')


if __name__ == '__main__':
    main()
