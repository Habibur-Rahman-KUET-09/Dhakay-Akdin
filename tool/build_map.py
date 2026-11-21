#!/usr/bin/env python3
"""Turns an area's real streets (tool/osm/<area>.json, from fetch_osm.py)
into the game's tile map (app/assets/content/maps/<area>.json).

    python3 tool/build_map.py mirpur [--png out.png]

The real streets run at an angle, so the map is turned until the area's
main road lies flat, then every street is laid on the grid: main roads
always, side streets only where they do not crowd a road already drawn,
so the lanes stay readable. Game features (tea stalls, signals,
waterlogging, one-way lanes, home) and the named places come from the
AREA settings below, given as real coordinates, so the map can be rebuilt
from new data without losing them.

Map data (c) OpenStreetMap contributors, ODbL 1.0.
"""
import json
import math
import os
import sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'app', 'assets', 'content', 'maps')

MAIN = {'trunk', 'primary', 'secondary'}
SIDE_MAIN = {'tertiary'}
LANES = {'residential', 'living_street', 'unclassified'}

AREAS = {
    'mirpur': {
        'name': {'bn': 'মিরপুর', 'en': 'Mirpur'},
        # The main road runs between these two roundabouts; it is laid flat.
        'axis': [(23.79973, 90.35515), (23.80715, 90.36878)],
        'cell_m': 45,
        # Along the axis (u) and across it (v), metres from its middle.
        'u': (-1150, 1150),
        'v': (-700, 1650),
        'roundabouts': [(23.79973, 90.35515), (23.80715, 90.36878)],
        'home': (23.7983, 90.3545),          # Kolwala Para, by Mirpur 1
        'tea': [(23.8064, 90.3632), (23.8013, 90.3525), (23.8095, 90.3685),
                (23.7972, 90.3487), (23.8040, 90.3570)],
        'signals': [(23.8054, 90.3640), (23.8030, 90.3600)],
        'flood': [(23.8085, 90.3690), (23.8058, 90.3665), (23.7980, 90.3575)],
        'one_way_lanes': 8,
        # Places a passenger can ask for: (id, bn, en, lat, lon).
        'places': [
            ('mirpur10', 'মিরপুর ১০ গোলচত্বর', 'Mirpur 10 roundabout', 23.80715, 90.36878),
            ('mirpur1', 'মিরপুর ১ গোলচত্বর', 'Mirpur 1 roundabout', 23.79973, 90.35515),
            ('zoo', 'চিড়িয়াখানা', 'National Zoo', 23.8122, 90.3469),
            ('stadium', 'শেরে বাংলা স্টেডিয়াম', 'Sher-e-Bangla Stadium', 23.8069, 90.3634),
            ('mazar', 'শাহ আলী মাজার', 'Shah Ali Mazar', 23.7968, 90.3484),
            ('commerce', 'ঢাকা কমার্স কলেজ', 'Dhaka Commerce College', 23.8067, 90.3529),
            ('bazar6', 'মিরপুর ৬ নং বাজার', 'Mirpur 6 Bazar', 23.8106, 90.3633),
            ('cinema', 'স্টার সিনেপ্লেক্স', 'Star Cineplex', 23.8004, 90.3553),
            ('busstand10', 'মিরপুর ১০ বাসস্ট্যান্ড', 'Mirpur 10 bus stand', 23.8074, 90.3682),
            ('dhankhet', 'ধানক্ষেতের মোড়', 'Dhankheter Mor', 23.79644, 90.360129),
            ('capital', 'ক্যাপিটাল টাওয়ার', 'Capital Tower', 23.7978, 90.35296),
            ('shialbari', 'শিয়ালবাড়ী', 'Shialbari', 23.8099, 90.3579),
            ('monipur', 'মনিপুর', 'Monipur', 23.8008, 90.3667),
            ('rupnagar', 'রূপনগর', 'Rupnagar', 23.8147, 90.3546),
            ('kolwala', 'কলওয়ালা পাড়া', 'Kolwala Para', 23.7983, 90.3544),
            ('falpotti', 'ফলপট্টি', 'Falpotti', 23.8061, 90.3681),
            ('borobagh', 'বড়বাগ', 'Borobagh', 23.8025, 90.3621),
            ('agora', 'আগোরা, মিরপুর ১০', 'Agora, Mirpur 10', 23.8095, 90.3689),
        ],
    },
}


class Frame:
    """Real coordinates to grid cells, turned so the axis lies flat."""

    def __init__(self, a):
        (la1, lo1), (la2, lo2) = a['axis']
        self.lat0, self.lon0 = (la1 + la2) / 2, (lo1 + lo2) / 2
        self.kx = 111320 * math.cos(math.radians(self.lat0))
        self.ky = 110574
        x, y = (lo2 - lo1) * self.kx, (la2 - la1) * self.ky
        self.t = math.atan2(y, x)
        self.cell = a['cell_m']
        self.u0, self.u1 = a['u']
        self.v0, self.v1 = a['v']
        self.w = int((self.u1 - self.u0) // self.cell)
        self.h = int((self.v1 - self.v0) // self.cell)

    def grid(self, lat, lon):
        x, y = (lon - self.lon0) * self.kx, (lat - self.lat0) * self.ky
        c, s = math.cos(self.t), math.sin(self.t)
        u, v = x * c + y * s, -x * s + y * c
        return (u - self.u0) / self.cell, (self.v1 - v) / self.cell

    def cell_of(self, lat, lon):
        gx, gy = self.grid(lat, lon)
        return int(gx), int(gy)

    def inside(self, c):
        return 1 <= c[0] < self.w - 1 and 1 <= c[1] < self.h - 1


def path_cells(f, pts):
    """The 4-connected cells a street passes through, in order."""
    out = []
    for (a, b) in zip(pts, pts[1:]):
        x0, y0 = f.grid(*a)
        x1, y1 = f.grid(*b)
        n = max(2, int(math.hypot(x1 - x0, y1 - y0) * 4))
        for i in range(n + 1):
            c = (int(x0 + (x1 - x0) * i / n), int(y0 + (y1 - y0) * i / n))
            if out and c == out[-1]:
                continue
            if out and abs(c[0] - out[-1][0]) + abs(c[1] - out[-1][1]) == 2:
                # A diagonal step: go round by the street's main direction.
                p = out[-1]
                if abs(x1 - x0) >= abs(y1 - y0):
                    out.append((c[0], p[1]))
                else:
                    out.append((p[0], c[1]))
            out.append(c)
    return out


def length_m(f, pts):
    return sum(math.hypot(*(p * f.cell for p in (
        f.grid(*b)[0] - f.grid(*a)[0], f.grid(*b)[1] - f.grid(*a)[1]))) for a, b in zip(pts, pts[1:]))


N4 = [(0, -1), (1, 0), (0, 1), (-1, 0)]
DIRS = {(0, -1): 'n', (1, 0): 'e', (0, 1): 's', (-1, 0): 'w'}


def build(area):
    a = AREAS[area]
    f = Frame(a)
    data = json.load(open(os.path.join(HERE, 'osm', f'{area}.json'), encoding='utf-8'))
    kind = {}       # cell -> 'M' main or '.' lane
    oneway = {}     # cell -> direction char

    def lay(cells, k):
        for c in cells:
            if f.inside(c) and kind.get(c) != 'M':
                kind[c] = k

    roads = data['roads']
    for r in roads:
        t = r['type'].replace('_link', '')
        if t in MAIN:
            lay(path_cells(f, r['pts']), 'M')
    for r in sorted(roads, key=lambda r: -length_m(f, r['pts'])):
        if r['type'].replace('_link', '') in SIDE_MAIN:
            lay(path_cells(f, r['pts']), '.')
    # Side streets, longest first, each only if it does not run alongside
    # a road already drawn (that would merge into a block of tarmac).
    for r in sorted(roads, key=lambda r: -length_m(f, r['pts'])):
        if r['type'] not in LANES or length_m(f, r['pts']) < 80:
            continue
        cells = [c for c in path_cells(f, r['pts']) if f.inside(c)]
        new = [c for c in cells if c not in kind]
        if len(new) < 3:
            continue
        if _parallel_run(cells, kind) >= 3:
            continue
        lay(cells, '.')
        if r.get('oneway') == 'yes' and r['type'] in ('residential', 'living_street'):
            for p, q in zip(cells, cells[1:]):
                d = DIRS.get((q[0] - p[0], q[1] - p[1]))
                if d and p in new:
                    oneway[p] = d

    _fill_blocks(kind)
    _prune(kind, f)

    grid = [['#'] * f.w for _ in range(f.h)]
    for (x, y), k in kind.items():
        grid[y][x] = k
    for (x, y), d in oneway.items():
        if kind.get((x, y)) == '.':
            grid[y][x] = d

    def near_road(lat, lon, allow=('.', 'M'), taken=()):
        cx, cy = f.cell_of(lat, lon)
        best = None
        for (x, y), k in kind.items():
            if grid[y][x] not in allow or (x, y) in taken:
                continue
            dd = (x - cx) ** 2 + (y - cy) ** 2
            if best is None or dd < best[0]:
                best = (dd, (x, y))
        return best[1]

    for lat, lon in a['roundabouts']:
        cx, cy = near_road(lat, lon, ('M',))
        # A ring of main road round a green island.
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                c = (cx + dx, cy + dy)
                if f.inside(c):
                    kind[c] = 'M'
                    grid[c[1]][c[0]] = 'M'
        grid[cy][cx] = 'O'
        kind.pop((cx, cy))
    for lat, lon in a['flood']:
        x, y = near_road(lat, lon)
        grid[y][x] = 'W'
    for lat, lon in a['signals']:
        x, y = near_road(lat, lon, ('M',))
        grid[y][x] = 'P'
    for lat, lon in a['tea']:
        x, y = near_road(lat, lon, ('.',))
        grid[y][x] = 'T'
    hx, hy = near_road(*a['home'], ('.',))
    grid[hy][hx] = 'H'
    _one_way(grid, a['one_way_lanes'], (hx, hy))

    places, taken = [], set()
    for pid, bn, en, lat, lon in a['places']:
        x, y = near_road(lat, lon, ('.', 'M', 'T', 'P'), taken)
        taken.add((x, y))
        places.append({'id': pid, 'name': {'bn': bn, 'en': en}, 'x': x, 'y': y})

    return {
        'id': area,
        'name': a['name'],
        'credit': 'Map data © OpenStreetMap contributors',
        'source': f"{data['source']}, fetched {data['fetched']}; built by tool/build_map.py",
        'tile_m': f.cell,
        'legend': {
            '#': 'building', 'O': 'roundabout island', '.': 'lane (two-way)',
            'M': 'main road (two-way)', 'n/e/s/w': 'one-way lane, the way it runs',
            'W': 'waterlogged', 'T': 'tea stall', 'P': 'traffic signal', 'H': 'home',
        },
        'places': places,
        'rows': [''.join(r) for r in grid],
    }


def _parallel_run(cells, kind):
    """The longest stretch where this street would run right beside a road
    already drawn. Crossing a road touches it for a cell or two; running
    alongside it for three or more would merge two streets into one."""
    own = set(cells)
    best = run = 0
    for i, c in enumerate(cells):
        a = cells[max(0, i - 1)]
        b = cells[min(len(cells) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        perp = [(-dy, dx), (dy, -dx)] if (dx or dy) else []
        crowded = c not in kind and any(
            (c[0] + int(math.copysign(1, px)) * (px != 0), c[1] + int(math.copysign(1, py)) * (py != 0)) in kind
            and (c[0] + int(math.copysign(1, px)) * (px != 0), c[1] + int(math.copysign(1, py)) * (py != 0)) not in own
            for px, py in perp)
        run = run + 1 if crowded else 0
        best = max(best, run)
    return best


def _fill_blocks(kind):
    """Thins every 2x2 square of road (a dual carriageway, or two streets
    merged) down to single-tile roads, never cutting a connection: a cell
    goes only if the roads around it stay joined without it. Side lanes go
    before main roads."""
    def removable(c):
        x, y = c
        ring = {(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                if (dx or dy) and (x + dx, y + dy) in kind}
        sides = [(x + dx, y + dy) for dx, dy in N4 if (x + dx, y + dy) in ring]
        if len(sides) < 2:
            return False
        seen = {sides[0]}
        q = [sides[0]]
        while q:
            a = q.pop()
            for dx, dy in N4:
                b = (a[0] + dx, a[1] + dy)
                if b in ring and b not in seen:
                    seen.add(b)
                    q.append(b)
        return all(s in seen for s in sides)

    for prefer in ('.', 'M'):
        changed = True
        while changed:
            changed = False
            for (x, y) in sorted(kind):
                sq = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
                if not all(c in kind for c in sq):
                    continue
                for c in sorted(sq, key=lambda c: (kind[c] != prefer, sum((c[0] + dx, c[1] + dy) in kind for dx, dy in N4))):
                    if kind[c] == prefer and removable(c):
                        del kind[c]
                        changed = True
                        break


def _one_way(grid, count, home):
    """Makes [count] quiet lanes one-way (the real ones mostly merged away
    on the grid): stretches of four or more lane tiles between turnings,
    spread over the map, each kept only if every road can still reach every
    other without going the wrong way."""
    h, w = len(grid), len(grid[0])
    road = lambda c: 0 <= c[0] < w and 0 <= c[1] < h and grid[c[1]][c[0]] not in '#O'
    nbrs = lambda c: [(c[0] + dx, c[1] + dy) for dx, dy in N4 if road((c[0] + dx, c[1] + dy))]
    chains, used = [], set()
    for y in range(h):
        for x in range(w):
            c = (x, y)
            if grid[y][x] != '.' or c in used or len(nbrs(c)) != 2:
                continue
            chain = [c]
            used.add(c)
            for end in (0, 1):
                cur = chain[-1] if end == 0 else chain[0]
                while True:
                    nxt = [n for n in nbrs(cur) if n not in used and grid[n[1]][n[0]] == '.' and len(nbrs(n)) == 2]
                    if not nxt:
                        break
                    used.add(nxt[0])
                    if end == 0:
                        chain.append(nxt[0])
                    else:
                        chain.insert(0, nxt[0])
                    cur = nxt[0]
            if len(chain) >= 4:
                chains.append(chain)

    def legal(a, b):
        d = (b[0] - a[0], b[1] - a[1])
        back = {'n': (0, 1), 'e': (-1, 0), 's': (0, -1), 'w': (1, 0)}
        return back.get(grid[a[1]][a[0]]) != d and back.get(grid[b[1]][b[0]]) != d

    def connected():
        cells = [(x, y) for y in range(h) for x in range(w) if road((x, y))]
        for forward in (True, False):
            seen, q = {home}, deque([home])
            while q:
                c = q.popleft()
                for n in nbrs(c):
                    ok = legal(c, n) if forward else legal(n, c)
                    if ok and n not in seen:
                        seen.add(n)
                        q.append(n)
            if len(seen) != len(cells):
                return False
        return True

    # Spread out: take chains in order of their middle along a coarse grid.
    chains.sort(key=lambda ch: (ch[len(ch) // 2][1] // 10 * 7 + ch[len(ch) // 2][0] // 10 * 3) % 11)
    made = 0
    for ch in chains:
        if made >= count:
            break
        if made % 2:
            ch = ch[::-1]
        old = [grid[c[1]][c[0]] for c in ch]
        for a_, b_ in zip(ch, ch[1:]):
            grid[a_[1]][a_[0]] = DIRS[(b_[0] - a_[0], b_[1] - a_[1])]
        last, before = ch[-1], ch[-2]
        grid[last[1]][last[0]] = DIRS[(last[0] - before[0], last[1] - before[1])]
        if connected():
            made += 1
        else:
            for c, o in zip(ch, old):
                grid[c[1]][c[0]] = o


def _prune(kind, f):
    """Removes short dead ends and anything not joined to the main roads."""
    for _ in range(3):
        for c in list(kind):
            if c in kind and kind[c] == '.':
                n = [(c[0] + dx, c[1] + dy) for dx, dy in N4 if (c[0] + dx, c[1] + dy) in kind]
                if len(n) <= 1:
                    del kind[c]
    start = next(c for c, k in kind.items() if k == 'M')
    seen = {start}
    q = deque([start])
    while q:
        c = q.popleft()
        for dx, dy in N4:
            n = (c[0] + dx, c[1] + dy)
            if n in kind and n not in seen:
                seen.add(n)
                q.append(n)
    for c in list(kind):
        if c not in seen:
            del kind[c]


def png(m, path, px=8):
    from PIL import Image, ImageDraw
    rows = m['rows']
    img = Image.new('RGB', (len(rows[0]) * px, len(rows) * px), (233, 220, 192))
    d = ImageDraw.Draw(img)
    col = {'#': (210, 190, 160), '.': (140, 143, 150), 'M': (60, 60, 70), 'W': (110, 180, 230),
           'T': (46, 158, 107), 'P': (226, 67, 42), 'H': (194, 24, 91), 'O': (90, 170, 90)}
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            d.rectangle([x * px, y * px, x * px + px - 1, y * px + px - 1], fill=col.get(ch, (170, 172, 178)))
    for p in m['places']:
        d.ellipse([p['x'] * px, p['y'] * px, p['x'] * px + px, p['y'] * px + px], outline=(255, 255, 0))
        d.text((p['x'] * px + px, p['y'] * px - 2), p['name']['en'], fill=(0, 0, 120))
    img.save(path)


def main():
    area = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else 'mirpur'
    m = build(area)
    path = os.path.join(OUT, f'{area}.json')
    with open(path, 'w', encoding='utf-8') as fh:
        fh.write(json.dumps({k: v for k, v in m.items() if k != 'rows'}, ensure_ascii=False, indent=2)[:-2])
        fh.write(',\n  "rows": [\n' + ',\n'.join(f'    "{r}"' for r in m['rows']) + '\n  ]\n}\n')
    roads = sum(r.count('.') + r.count('M') for r in m['rows'])
    print(f'{path}: {len(m["rows"][0])}x{len(m["rows"])}, {roads} road tiles, {len(m["places"])} places')
    if '--png' in sys.argv:
        png(m, sys.argv[sys.argv.index('--png') + 1])


if __name__ == '__main__':
    main()
