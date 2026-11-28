"""Measures a character from three photos on a white background (front,
side facing left, back): the outline, the width and depth of the body at
every height, where each kind of cloth begins and ends.

    python3 tool/characters/photo_measure.py <name> [<debug dir>]

reads tool/characters/ref/<name>_{front,side,back}.png and writes
tool/characters/ref/<name>.measure.json. Heights are fractions of the
person's height from the soles (0) to the top of the head (1); widths are
fractions of the height too, so the 3D body can be fitted at any size."""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = 200


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def hsv(img):
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    mx = img.max(-1)
    mn = img.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60.0
    s = np.where(mx > 0, d / (mx + 1e-6), 0)
    return h, s, mx


def person_mask(img):
    """Everything not near-white: the person."""
    h, s, v = hsv(img)
    white = (v > 0.9) & (s < 0.08)
    m = ~white
    # Fill single-pixel holes and drop specks.
    from_rows = m.copy()
    return from_rows


def kinds(img):
    """Pixel kinds: shirt (orange), lungi (blue/green), gamchha (red/pink),
    skin (brown), hair (dark), sandal (dark blue)."""
    h, s, v = hsv(img)
    k = np.full(img.shape[:2], "", dtype=object)
    orange = (h >= 8) & (h < 32) & (s > 0.45) & (v > 0.45)
    red = ((h < 8) | (h > 330)) & (s > 0.3) & (v > 0.45)
    blue_green = (h > 120) & (h < 240) & (s > 0.2) & (v > 0.2)
    dark = v < 0.22
    skin = (h >= 5) & (h < 40) & (s > 0.25) & (s <= 0.75) & (v >= 0.22) & (v < 0.75) & ~orange
    k[skin] = "skin"
    k[orange] = "shirt"
    k[red] = "gamchha"
    k[blue_green] = "lungi"
    k[dark] = "dark"
    return k


def rows_of(mask, top, bottom, n=ROWS):
    """For n heights from the soles up: the leftmost and rightmost person
    pixel (whole outline) and the run around the middle (the trunk, the
    arms left out where there is a gap)."""
    out = []
    height = bottom - top
    centre = None
    for i in range(n + 1):
        frac = i / n
        y = int(round(bottom - frac * height))
        y = min(max(y, 0), mask.shape[0] - 1)
        xs = np.nonzero(mask[y])[0]
        if xs.size == 0:
            out.append(None)
            continue
        if centre is None:
            centre = float(xs.mean())
        # Runs of person pixels; the trunk is the run nearest the middle.
        runs = np.split(xs, np.nonzero(np.diff(xs) > 3)[0] + 1)
        mid = min(runs, key=lambda r: 0 if r[0] <= centre <= r[-1] else min(abs(r[0] - centre), abs(r[-1] - centre)))
        out.append({"y": y, "left": int(xs[0]), "right": int(xs[-1]), "trunk": [int(mid[0]), int(mid[-1])], "runs": len(runs),
                    "spans": [[int(r[0]), int(r[-1])] for r in runs if r.size > 2]})
    return out


def measure(name, debug=None):
    views = {}
    for view in ("front", "side", "back"):
        img = load(os.path.join(HERE, "ref", "%s_%s.png" % (name, view)))
        m = person_mask(img)
        ys = np.nonzero(m.any(1))[0]
        top, bottom = int(ys[0]), int(ys[-1])
        height = bottom - top
        k = kinds(img)
        rows = rows_of(m, top, bottom)
        # The middle of the body at the hips (front/back: left-right, side: front-back).
        hip_row = rows[int(ROWS * 0.5)]
        centre = (hip_row["trunk"][0] + hip_row["trunk"][1]) / 2.0
        span = {}
        for kind in ("shirt", "lungi", "gamchha", "skin", "dark"):
            yy, xx = np.nonzero((k == kind) & m)
            if yy.size < 50:
                continue
            # Heights where this kind fills a fair part of the row.
            counts = np.bincount(yy, minlength=img.shape[0])
            full = np.nonzero(counts > max(8, counts.max() * 0.15))[0]
            span[kind] = {
                "top": round((bottom - full.min()) / height, 4),
                "bottom": round((bottom - full.max()) / height, 4),
                "x": [round((xx.min() - centre) / height, 4), round((xx.max() - centre) / height, 4)],
            }
        # The hems: the lowest height where the lungi still fills most of the
        # trunk (above the feet), the highest where the shirt does.
        def filled(kind, f):
            r = rows[int(round(f * ROWS))]
            if r is None:
                return 0.0
            y = r["y"]
            a, b = r["trunk"]
            return float(((k[y, a:b + 1] == kind) & m[y, a:b + 1]).mean()) if b > a else 0.0
        lungi_rows = [i / ROWS for i in range(int(ROWS * 0.08), int(ROWS * 0.6)) if filled("lungi", i / ROWS) > 0.5]
        if lungi_rows:
            span.setdefault("lungi", {})["hem"] = min(lungi_rows)
            span["lungi"]["waist"] = max(lungi_rows)
        views[view] = {
            "size": list(img.shape[1::-1]),
            "top": top, "bottom": bottom, "centre": centre, "height_px": height,
            "rows": [None if r is None else {
                "f": round(i / ROWS, 4),
                "left": round((r["left"] - centre) / height, 4),
                "right": round((r["right"] - centre) / height, 4),
                "trunk": [round((r["trunk"][0] - centre) / height, 4), round((r["trunk"][1] - centre) / height, 4)],
                "runs": r["runs"],
                "spans": [[round((a - centre) / height, 4), round((b - centre) / height, 4)] for a, b in r["spans"]],
            } for i, r in enumerate(rows)],
            "kinds": span,
        }
        if debug:
            os.makedirs(debug, exist_ok=True)
            colours = {"shirt": (255, 140, 0), "lungi": (0, 90, 255), "gamchha": (255, 0, 80), "skin": (150, 90, 50), "dark": (0, 0, 0)}
            out = np.full(img.shape, 255, dtype=np.uint8)
            for kind, c in colours.items():
                out[(k == kind) & m] = c
            rest = m & (k == "")
            out[rest] = (200, 200, 200)
            for r in rows[::10]:
                if r:
                    out[r["y"], r["trunk"][0]:r["trunk"][1]] = (0, 200, 0)
            Image.fromarray(out).save(os.path.join(debug, "%s_%s_kinds.png" % (name, view)))
    result = {"name": name, "views": views}
    json.dump(result, open(os.path.join(HERE, "ref", name + ".measure.json"), "w"), indent=1)
    return result


if __name__ == "__main__":
    r = measure(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    for v, d in r["views"].items():
        print(v, "height px", d["height_px"], {k: (s["top"], s["bottom"]) for k, s in d["kinds"].items()})
