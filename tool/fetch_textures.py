#!/usr/bin/env python3
"""Downloads photo textures for the town from Poly Haven (all CC0).

    python3 tool/fetch_textures.py

For each slot below it asks the Poly Haven API for textures whose
categories or tags match, takes the most downloaded one, and saves its
1k diffuse (colour) map as game/textures/<slot>.jpg (the game uses them
resized to 512 px: run tool/fetch_textures.py, then resize). game/textures/
SOURCES.json records which asset each file came from. Run by the
textures workflow, which has open internet.

Poly Haven assets are CC0 (https://polyhaven.com/license).
"""
import json
import os
import sys
import urllib.request

API = 'https://api.polyhaven.com'
UA = {'User-Agent': 'dhakar-ekdin-texture-fetch/1.0'}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'game', 'textures')

# slot: words to look for, in order of preference; words to avoid.
SLOTS = {
    'asphalt': (['asphalt', 'road'], ['snow', 'marking', 'line']),
    'pavement': (['pavement', 'paving', 'sidewalk', 'tiles'], ['roof', 'wood', 'ceramic', 'snow']),
    'plaster': (['plaster', 'painted', 'stucco', 'wall'], ['brick', 'wood', 'snow', 'tile']),
    'shutter': (['corrugated', 'metal', 'rusty'], ['floor', 'grate', 'snow']),
    'brick': (['brick'], ['snow', 'white']),
}


def get(path):
    req = urllib.request.Request(API + path, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def words(info):
    return [w.lower() for w in info.get('categories', []) + info.get('tags', [])] + info.get('name', '').lower().split()


def pick(assets, want, avoid, taken):
    for w in want:
        found = [
            (info.get('download_count', 0), aid) for aid, info in assets.items()
            if aid not in taken and any(w in x for x in words(info)) and not any(a in x for a in avoid for x in words(info))
        ]
        if found:
            return max(found)[1]
    return None


def diffuse_url(files):
    for key in ('Diffuse', 'diffuse', 'Color', 'col'):
        try:
            return files[key]['1k']['jpg']['url']
        except (KeyError, TypeError):
            continue
    return None


def main():
    os.makedirs(OUT, exist_ok=True)
    assets = get('/assets?t=textures')
    print(f'{len(assets)} textures on Poly Haven')
    sources, taken = {}, set()
    for slot, (want, avoid) in SLOTS.items():
        aid = pick(assets, want, avoid, taken)
        if not aid:
            print(f'{slot}: nothing found', file=sys.stderr)
            continue
        url = diffuse_url(get(f'/files/{aid}'))
        if not url:
            print(f'{slot}: {aid} has no 1k jpg diffuse', file=sys.stderr)
            continue
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=120) as r, open(os.path.join(OUT, f'{slot}.jpg'), 'wb') as f:
            f.write(r.read())
        taken.add(aid)
        sources[slot] = {'asset': aid, 'name': assets[aid].get('name'), 'url': f'https://polyhaven.com/a/{aid}', 'license': 'CC0'}
        print(f'{slot}: {aid} ({assets[aid].get("name")})')
    with open(os.path.join(OUT, 'SOURCES.json'), 'w') as f:
        json.dump(sources, f, indent=1)


if __name__ == '__main__':
    main()
