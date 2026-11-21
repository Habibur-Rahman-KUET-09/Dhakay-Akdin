#!/usr/bin/env python3
"""Downloads the real streets and places of a game area from OpenStreetMap.

    python3 tool/fetch_osm.py mirpur

Writes tool/osm/<area>.json: roads (type, name, one-way, points) and named
places (kind, name in Bangla and English, point). tool/build_map.py turns
it into the game's tile map. Run by the osm workflow, which has open
internet.

Map data (c) OpenStreetMap contributors, ODbL 1.0
(https://www.openstreetmap.org/copyright). The game credits them.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request

AREAS = {
    # south, west, north, east: Mirpur 1 and the zoo to Mirpur 10 and 11.
    'mirpur': (23.792, 90.345, 23.816, 90.372),
}
SERVERS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
]
ROADS = 'trunk|primary|secondary|tertiary|residential|unclassified|living_street'


def query(bbox):
    b = ','.join(str(x) for x in bbox)
    return f"""[out:json][timeout:120];
(
  way["highway"~"^({ROADS})(_link)?$"]({b});
  nwr["name"]["amenity"~"^(marketplace|place_of_worship|hospital|school|college|university|bus_station|cinema)$"]({b});
  nwr["name"]["leisure"~"^(stadium|park)$"]({b});
  nwr["name"]["tourism"~"^(zoo|attraction)$"]({b});
  nwr["name"]["shop"="mall"]({b});
  node["name"]["highway"="bus_stop"]({b});
  node["name"]["place"]({b});
  node["name"]["junction"]({b});
  way["name"]["junction"="roundabout"]({b});
);
out tags center geom;"""


def fetch(q):
    data = urllib.parse.urlencode({'data': q}).encode()
    last = None
    for attempt in range(3):
        for url in SERVERS:
            try:
                req = urllib.request.Request(url, data, {'User-Agent': 'dhakar-ekdin-map-builder/1.0'})
                with urllib.request.urlopen(req, timeout=180) as r:
                    return json.load(r)
            except Exception as e:  # try the next server
                last = e
                print(f'{url}: {e}', file=sys.stderr)
        time.sleep(20 * (attempt + 1))
    raise SystemExit(f'all Overpass servers failed: {last}')


def simplify(raw):
    roads, places = [], []
    for el in raw['elements']:
        t = el.get('tags', {})
        if el['type'] == 'way' and 'highway' in t and 'geometry' in el and t['highway'].replace('_link', '') in ROADS.split('|'):
            roads.append({
                'id': el['id'],
                'type': t['highway'],
                'name': t.get('name:en') or t.get('name'),
                'name_bn': t.get('name:bn'),
                'oneway': t.get('oneway'),
                'pts': [[round(p['lat'], 6), round(p['lon'], 6)] for p in el['geometry']],
            })
            if t.get('junction') != 'roundabout' or 'name' not in t:
                continue
        if 'name' not in t:
            continue
        c = el.get('center') or ({'lat': el['lat'], 'lon': el['lon']} if 'lat' in el else None)
        if c is None:
            continue
        kind = next((f'{k}={t[k]}' for k in ('amenity', 'leisure', 'tourism', 'shop', 'highway', 'place', 'junction') if k in t), 'other')
        places.append({
            'id': f"{el['type'][0]}{el['id']}",
            'kind': kind,
            'name': t.get('name:en') or t.get('name'),
            'name_bn': t.get('name:bn'),
            'pt': [round(c['lat'], 6), round(c['lon'], 6)],
        })
    return {'roads': roads, 'places': places}


def main():
    area = sys.argv[1] if len(sys.argv) > 1 else 'mirpur'
    bbox = AREAS[area]
    out = simplify(fetch(query(bbox)))
    out = {'area': area, 'bbox': bbox, 'source': 'OpenStreetMap contributors, ODbL 1.0',
           'fetched': time.strftime('%Y-%m-%d'), **out}
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'osm', f'{area}.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{path}: {len(out["roads"])} roads, {len(out["places"])} places')


if __name__ == '__main__':
    main()
