"""Dresses and paints a MakeHuman body from three photos of the person
(front, side facing left, back, on white; measured by photo_measure.py):

1. the arms are posed down as in the photos and that pose made the rest pose;
2. the clothes are made to the photos' outline (the lungi's width and depth
   at each height, the shirt's hem and sleeve ends, the gamchha's strips
   front and back), the body under them taken away;
3. every texel of every mesh is painted from the photos: where it is on the
   person, seen from the front, the back or the side (weighted by which way
   the surface faces; a photo's white background is never used), mapped by
   landmarks (soles, chin, mouth, eyes, top of the head) so the face falls
   on the face.

Blender is Z up, the body faces -Y, his left is +X. Photo fractions: 0 at
the soles, 1 at the top of the head."""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import clothes


# --- Photos ---------------------------------------------------------------------------


class Photo:
    def __init__(self, path, view_data):
        img = bpy.data.images.load(path)
        w, h = img.size
        px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
        bpy.data.images.remove(img)
        self.px = px
        self.w, self.h = w, h
        self.top = view_data["top"]
        self.bottom = view_data["bottom"]
        self.hpx = view_data["height_px"]
        self.centre = view_data["centre"]
        self.rows = view_data["rows"]
        mx = px.max(-1)
        mn = px.min(-1)
        self.background = (mx > 0.86) & ((mx - mn) / (mx + 1e-6) < 0.12)
        self._nearest()

    def _nearest(self, reach=40):
        """For each background pixel near the person, the nearest person
        pixel (a model a little wider than the photo then takes the cloth's
        colour at its edge, not the white)."""
        h, w = self.background.shape
        person = ~self.background
        # Not the very edge (half white): a few pixels in.
        for _ in range(5):
            person = person & np.roll(person, 1, 0) & np.roll(person, -1, 0) & np.roll(person, 1, 1) & np.roll(person, -1, 1)
        ny, nx = np.mgrid[0:h, 0:w]
        ny = np.where(person, ny, -10 ** 6).astype(np.int32)
        nx = np.where(person, nx, -10 ** 6).astype(np.int32)
        yy, xx = np.mgrid[0:h, 0:w]
        for _ in range(reach):
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cy = np.roll(ny, dy, 0) if dy else ny
                cx = np.roll(nx, dy, 0) if dy else nx
                if dx:
                    cy = np.roll(cy, dx, 1)
                    cx = np.roll(cx, dx, 1)
                d_new = (cy - yy) ** 2 + (cx - xx) ** 2
                d_old = (ny - yy) ** 2 + (nx - xx) ** 2
                better = d_new < d_old
                ny = np.where(better, cy, ny)
                nx = np.where(better, cx, nx)
        dist2 = (ny - yy) ** 2 + (nx - xx) ** 2
        self.solid = person
        self.near_ok = dist2 <= reach * reach
        self.near_y = np.clip(ny, 0, h - 1)
        self.near_x = np.clip(nx, 0, w - 1)

    def y_of(self, f):
        return self.bottom - f * self.hpx

    def f_of_px(self, y):
        return (self.bottom - y) / self.hpx

    def sample(self, xs, ys):
        """Colours at pixel positions (arrays), and whether each is on the
        person (not the white background, inside the picture)."""
        xi = np.clip(np.round(xs).astype(int), 0, self.w - 1)
        yi = np.clip(np.round(ys).astype(int), 0, self.h - 1)
        inside = (xs >= 0) & (xs < self.w) & (ys >= 0) & (ys < self.h)
        on = self.solid[yi, xi]
        # Just off the person (or on its pale edge): the nearest solid part
        # of the person instead.
        near = ~on & self.near_ok[yi, xi]
        sy = np.where(near, self.near_y[yi, xi], yi)
        sx = np.where(near, self.near_x[yi, xi], xi)
        ok = inside & (on | near)
        return self.px[sy, sx], ok

    def row(self, f):
        i = int(round(min(max(f, 0.0), 1.0) * (len(self.rows) - 1)))
        return self.rows[i]


# --- Model landmarks ----------------------------------------------------------------------


def group_points(obj, names):
    idx = {obj.vertex_groups[n].index for n in names if n in obj.vertex_groups}
    pts = []
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in idx and g.weight > 0.5:
                pts.append(obj.matrix_world @ v.co)
                break
    return pts


def model_landmarks(body, eyes_obj):
    co = body.co
    zs = [c.z for c in co]
    floor = min(zs)
    lm = {"sole": floor}
    if eyes_obj is not None:
        bb = [eyes_obj.matrix_world @ Vector(c) for c in eyes_obj.bound_box]
        lm["eyes"] = sum(p.z for p in bb) / 8.0
    lips = group_points(body.obj, ["lips"])
    if lips:
        lm["mouth"] = sum(p.z for p in lips) / len(lips)
    head = [c for i, c in enumerate(co) if body.top_group[i] in ("head", "scalp", "ears", "lips")]
    lm["skull"] = max(c.z for c in head) if head else max(zs)
    front_head = [c for c in head if c.y < -0.03 and abs(c.x) < 0.04]
    if "mouth" in lm and front_head:
        below = [c.z for c in front_head if c.z < lm["mouth"]]
        lm["chin"] = min(below) if below else lm["mouth"] - 0.04
    ears = group_points(body.obj, ["ears"])
    if ears:
        lm["ear_x"] = (min(p.x for p in ears), max(p.x for p in ears))
    if head:
        lm["head_y"] = (min(c.y for c in head), max(c.y for c in head))
    return lm


class Mapping:
    """Model point → photo pixel, per view: heights by landmarks, sideways
    by the person's height (the head by its own width), arms moved onto
    the photo's arms."""

    def __init__(self, lm, photos, marks, height):
        self.lm = lm
        self.photos = photos
        self.height = height
        self.knots = {}
        for view, ph in photos.items():
            m = marks.get(view, {})
            mz = [lm["sole"]]
            pf = [0.0]
            for key in ("chin", "mouth", "eyes", "skull"):
                if key in lm and key in m:
                    mz.append(lm[key])
                    pf.append(ph.f_of_px(m[key]))
            self.knots[view] = (np.array(mz), np.array(pf))
        self.marks = marks

    def f(self, view, z):
        mz, pf = self.knots[view]
        # Past the last knot: on at the body's own scale.
        out = np.interp(z, mz, pf)
        top = z > mz[-1]
        out[top] = pf[-1] + (z[top] - mz[-1]) / self.height
        return out

    def head_weight(self, z):
        chin = self.lm.get("chin", self.lm["sole"] + self.height * 0.86)
        return np.clip((z - (chin - 0.03)) / 0.04, 0.0, 1.0)

    def to_px(self, view, p, arm_shift=None):
        """p: (n, 3) model points → (xs, ys) pixels in that view's photo."""
        ph = self.photos[view]
        x, y, z = p[:, 0], p[:, 1], p[:, 2]
        f = self.f(view, z)
        ys = ph.y_of(f)
        hw = self.head_weight(z)
        m = self.marks.get(view, {})
        if view in ("front", "back"):
            sign = 1.0 if view == "front" else -1.0
            body_u = x / self.height * ph.hpx
            if arm_shift is not None:
                body_u = body_u + arm_shift
            head_u = body_u
            if "ears" in m and "ear_x" in self.lm:
                ex0, ex1 = self.lm["ear_x"]
                px0, px1 = m["ears"]
                k = (px1 - px0) / max(1e-6, ex1 - ex0)
                head_u = (x - (ex0 + ex1) / 2.0) * k + ((px0 + px1) / 2.0 - ph.centre) * sign
            u = body_u * (1 - hw) + head_u * hw
            xs = ph.centre + sign * u
        else:
            body_u = y / self.height * ph.hpx + m.get("body_dx", 0.0)
            head_u = body_u
            if "nose_back" in m and "head_y" in self.lm:
                hy0, hy1 = self.lm["head_y"]
                px0, px1 = m["nose_back"]
                k = (px1 - px0) / max(1e-6, hy1 - hy0)
                head_u = (y - hy0) * k + (px0 - ph.centre)
            u = body_u * (1 - hw) + head_u * hw
            xs = ph.centre + u
        return xs, ys


# --- Posing as in the photos ------------------------------------------------------------------


def pose_arms_down(rig, out_deg=7.0):
    """Upper arms down beside the body, a little out; forearms on in line.
    Then the pose becomes the rest pose (the meshes baked into it)."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for side, upper, lower in ((1, "upperarm_l", "lowerarm_l"), (-1, "upperarm_r", "lowerarm_r")):
        if upper not in rig.pose.bones:
            continue
        b = rig.data.bones[upper]
        # Which side the arm is on, from where it points.
        along = (b.tail_local - b.head_local).normalized()
        s = 1.0 if along.x > 0 else -1.0
        target = Vector((s * math.sin(math.radians(out_deg)), 0.02, -math.cos(math.radians(out_deg)))).normalized()
        for name in (upper, lower):
            if name not in rig.pose.bones:
                continue
            bone = rig.data.bones[name]
            pb = rig.pose.bones[name]
            bpy.context.view_layer.update()
            cur = (pb.tail - pb.head).normalized()
            rot = cur.rotation_difference(target if name == upper else (target + Vector((0, -0.12, 0))).normalized())
            head = pb.head.copy()
            pb.matrix = Matrix.Translation(head) @ rot.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
            bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    # Bake the pose into every mesh, then make it the rest pose.
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        for ob in bpy.context.view_layer.objects:
            ob.select_set(ob == o)
        if o.data.shape_keys:
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
        for m in list(o.modifiers):
            if m.type in ("MASK", "SUBSURF"):
                try:
                    bpy.ops.object.modifier_apply(modifier=m.name)
                except Exception:
                    o.modifiers.remove(m)
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = rig
    for ob in bpy.context.view_layer.objects:
        ob.select_set(ob == rig)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in meshes:
        am = o.modifiers.new("rig", "ARMATURE")
        am.object = rig


# --- Clothes from the photos -----------------------------------------------------------------------


def lungi_from_photos(body, mapping, photos, spec):
    """A tube from the waist to the hem, as wide (front photo) and as deep
    (side photo) as the lungi is at each height."""
    fr, sd = photos["front"], photos["side"]
    waist_f, hem_f = spec["waist"], spec["hem"]
    rings, sides = 18, 40
    H = mapping.height
    # Model heights for photo fractions (front view's knots, inverted).
    mz, pf = mapping.knots["front"]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rows = []
    for r in range(rings + 1):
        f = waist_f + (hem_f - waist_f) * r / rings
        z = float(np.interp(f, pf, mz))
        a = fr.row(f)
        b = sd.row(f)
        if a is None or b is None:
            continue
        x0, x1 = a["trunk"]
        y0, y1 = b["trunk"]
        cx = (x0 + x1) / 2 * H
        hx = (x1 - x0) / 2 * H + spec.get("ease", 0.006)
        cy = (y0 + y1) / 2 * H - spec.get("body_dy", 0.0)
        hy = (y1 - y0) / 2 * H + spec.get("ease", 0.006)
        row = []
        for s in range(sides):
            ang = s * math.tau / sides
            # A rounded box (cloth over two legs is not an ellipse).
            c, si = math.cos(ang), math.sin(ang)
            ex = 2.0 / 3.0
            px = cx + hx * math.copysign(abs(c) ** ex, c)
            py = cy + hy * math.copysign(abs(si) ** ex, si)
            row.append(bm.verts.new((px, py, z)))
        rows.append(row)
    for r in range(len(rows) - 1):
        for s in range(sides):
            s2 = (s + 1) % sides
            face = bm.faces.new((rows[r][s], rows[r][s2], rows[r + 1][s2], rows[r + 1][s]))
            for loop, (uu, vv) in zip(face.loops, [(s, r), (s + 1, r), (s + 1, r + 1), (s, r + 1)]):
                loop[uv].uv = (uu / sides, vv / max(1, len(rows) - 1))
    bm.normal_update()
    mat = bpy.data.materials.new("lungi")
    obj = clothes.new_object("lungi", bm, mat)
    clothes.bind(obj, body.obj)
    return obj


def shirt_from_photos(body, mapping, spec):
    """The body's surface from the shirt's hem to the neck, the sleeves to
    where they end in the photo, loose."""
    mz, pf = mapping.knots["front"]
    bottom = float(np.interp(spec["hem"], pf, mz))
    neck = float(np.interp(spec["neck"], pf, mz))
    sleeve_z = float(np.interp(spec["sleeve"], pf, mz))
    src = body.obj
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(src.evaluated_get(deps))
    mesh.transform(src.matrix_world)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    bm.verts.ensure_lookup_table()
    keep = set()
    for v in bm.verts:
        c = v.co
        g = body.top_group[v.index]
        if c.z < bottom or c.z > neck:
            continue
        if any(w in g for w in ("thigh", "calf", "foot", "ball", "head", "neck")):
            continue
        if body.is_arm(v.index) and c.z < sleeve_z:
            continue
        keep.add(v.index)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    for e in bm.edges:
        if not e.is_boundary:
            continue
        for v in e.verts:
            if v.co.z < bottom + 0.05:
                v.co.z = bottom
            elif v.co.z > neck - 0.05:
                v.co.z = min(v.co.z, neck)
    bm.normal_update()
    for v in bm.verts:
        lift = spec.get("lift", 0.016)
        if v.co.z < bottom + 0.15:
            lift += 0.02 * (1.0 - (v.co.z - bottom) / 0.15)
        v.co += v.normal * lift
    mat = bpy.data.materials.new("shirt")
    obj = clothes.new_object("shirt", bm, mat)
    clothes.bind(obj, body.obj)
    return obj


def gamchha_from_photos(body, mapping, photos, spec):
    """Two strips where the photos show the red cloth (front and back, on
    his left shoulder), joined over the shoulder, a little thick."""
    H = mapping.height
    mz, pf = mapping.knots["front"]
    top_f, bottom_front, bottom_back = spec["top"], spec["bottom_front"], spec["bottom_back"]
    x0f, x1f = spec["x_front"]
    x0b, x1b = spec["x_back"]
    rows = []
    off = spec.get("off", 0.035)

    def surface_y(x, z, front):
        pts = [body.co[i] for i in range(len(body.co)) if abs(body.co[i].x - x) < 0.03 and abs(body.co[i].z - z) < 0.03
               and not any(w in body.top_group[i] for w in ("hand", "lowerarm"))]
        if not pts:
            return None
        return (min(p.y for p in pts) - off) if front else (max(p.y for p in pts) + off)

    n = 8
    front_rows, back_rows = [], []
    for k in range(n + 1):
        f = bottom_front + (top_f - bottom_front) * k / n
        z = float(np.interp(f, pf, mz))
        row = []
        for x in (x0f * H, x1f * H):
            y = surface_y(x, z, True)
            if y is not None:
                row.append(Vector((x, y, z)))
        if len(row) == 2:
            front_rows.append(row)
    for k in range(n + 1):
        f = top_f + (bottom_back - top_f) * k / n
        z = float(np.interp(f, pf, mz))
        row = []
        # The back photo is mirrored: his left is on its left.
        for x in (-x1b * H, -x0b * H):
            y = surface_y(x, z, False)
            if y is not None:
                row.append(Vector((x, y, z)))
        if len(row) == 2:
            back_rows.append(row)
    # Over the shoulder: rows from the top front row to the top back row,
    # each lying on the top of the shoulder there (the highest body point
    # near it, not the head or the arm below), so it drapes, not a flat lid.
    torso = [i for i in range(len(body.co))
             if not any(w in body.top_group[i] for w in ("head", "ears", "scalp", "lips", "neck", "hand", "lowerarm"))]

    def top_z(x, y, floor_z):
        zs = [body.co[i].z for i in torso if abs(body.co[i].x - x) < 0.02 and abs(body.co[i].y - y) < 0.02]
        return max([floor_z] + zs)

    if front_rows and back_rows:
        a, b = front_rows[-1], back_rows[0]
        mids = []
        m = 6
        for k in range(1, m):
            t = k / m
            row = []
            for i in range(2):
                p = a[i].lerp(b[i], t)
                # A rounded arch: never below the line, lifted by the cloth.
                arch = math.sin(t * math.pi) * 0.012
                # Never above the higher end row by more than the arch: the
                # neck beside it must not lift the cloth.
                z = min(top_z(p.x, p.y, p.z - 0.2) + off * 0.8, max(a[i].z, b[i].z) + 0.03) + arch
                row.append(Vector((p.x, p.y, z)))
            mids.append(row)
        rows = front_rows + mids + back_rows
    else:
        rows = front_rows + back_rows
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    vrows = [[bm.verts.new(p) for p in row] for row in rows]
    for k in range(len(vrows) - 1):
        face = bm.faces.new((vrows[k][0], vrows[k][1], vrows[k + 1][1], vrows[k + 1][0]))
        for loop, (uu, vv) in zip(face.loops, [(0, k), (1, k), (1, k + 1), (0, k + 1)]):
            loop[uv].uv = (uu, vv / max(1, len(vrows) - 1))
    bm.normal_update()
    mat = bpy.data.materials.new("gamchha")
    mat.use_backface_culling = False
    obj = clothes.new_object("gamchha", bm, mat)
    sol = obj.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = spec.get("thick", 0.02)
    bpy.context.view_layer.objects.active = obj
    for ob in bpy.context.view_layer.objects:
        ob.select_set(ob == obj)
    bpy.ops.object.modifier_apply(modifier=sol.name)
    clothes.bind(obj, body.obj)
    return obj


def trim_by_colour(obj, mapping, photos, keep, region=None, side_mirror_above=None):
    """Takes away the faces of obj that the photos show as something else
    (keep(colours) is False), inside region(centres, normals) if given: the
    hair cap where there is skin, the shirt's open collar. A face goes only
    if most faces around it go too, so the edge is clean. Returns how many
    went."""
    mw = obj.matrix_world
    nm = mw.to_3x3()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    if not bm.faces:
        bm.free()
        return 0
    cs = np.array([tuple(mw @ f.calc_center_median()) for f in bm.faces])
    ns = np.array([tuple((nm @ f.normal).normalized()) for f in bm.faces])
    col, w = colour_at(cs, ns, mapping, photos, None, side_mirror_above)
    go = (keep(col) < 0.5) & (w > 1e-3)
    if region is not None:
        go &= region(cs, ns)
    # One pass of the majority of each face's neighbours (by edge).
    index = {f: i for i, f in enumerate(bm.faces)}
    smooth = go.copy()
    for f in bm.faces:
        near = {index[g] for e in f.edges for g in e.link_faces if g is not f}
        if near:
            votes = sum(1 for j in near if go[j])
            smooth[index[f]] = (votes + (1 if go[index[f]] else 0)) * 2 > len(near) + 1
    gone = [f for f in bm.faces if smooth[index[f]]]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(gone)


def hair_like(col):
    """Hair: dark, or grey (little colour); skin is brown and stronger."""
    mx = col.max(1)
    ch = mx - col.min(1)
    sat = ch / np.maximum(mx, 1e-6)
    return ((mx < 0.42) | (sat < 0.22)).astype(np.float32)


def hide_under(body_obj, shirt_hem_z, lungi_hem_z):
    """Takes away the skin under the shirt and the lungi (it would poke
    through and is never seen)."""
    names = {g.index: g.name.lower() for g in body_obj.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(body_obj.data)
    deform = bm.verts.layers.deform.active
    gone = []
    for v in bm.verts:
        best, w = "", 0.0
        for gi, gw in v[deform].items():
            n = names.get(gi, "")
            if gw > w and n in ("pelvis", "spine_01", "spine_02", "spine_03", "thigh_l", "thigh_r"):
                best, w = n, gw
        z = (body_obj.matrix_world @ v.co).z
        if best and w > 0.6 and lungi_hem_z + 0.06 < z < shirt_hem_z + 0.25:
            gone.append(v)
    bmesh.ops.delete(bm, geom=gone, context="VERTS")
    bm.to_mesh(body_obj.data)
    bm.free()


# --- Painting from the photos -----------------------------------------------------------------------


# --- A shape made by an image-to-3D model (ai3d.py) -------------------------------------------------


def ai_body(path, body, spec):
    """The AI's shape of him (a .glb of one bare mesh) in place of the
    MakeHuman body: fewer faces for a phone, his height and standing where
    the body stands (feet on its floor, the middle of his hips on x = 0 and
    y = 0, as the photos are measured), smooth."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        raise RuntimeError("no mesh in " + path)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = meshes[0]
    mw = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = mw
    for o in bpy.context.view_layer.objects:
        o.select_set(o == obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o != obj and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)
    obj.name = "ai_body"
    me = obj.data
    me.materials.clear()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    faces = len(me.polygons)
    target = spec.get("faces", 24000)
    if faces > target:
        dec = obj.modifiers.new("fewer", "DECIMATE")
        dec.ratio = target / faces
        dec.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dec.name)
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    z0, z1 = co[:, 2].min(), co[:, 2].max()
    co = (co - np.array([0.0, 0.0, z0])) * (body.height / (z1 - z0))
    band = np.abs(co[:, 2] - body.height * 0.5) < body.height * 0.012
    cx = (co[band, 0].min() + co[band, 0].max()) / 2.0
    cy = (co[band, 1].min() + co[band, 1].max()) / 2.0
    co[:, 0] -= cx
    co[:, 1] -= cy
    co[:, 2] += body.floor
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    return obj


def ai_landmarks(obj, body, photos, marks):
    """Where the AI's shape has the head's marks, so its face meets the
    photo's: the tip of the nose (the most forward point between mouth and
    eyes) sets the eyes, mouth, chin and skull at the photo's spacing; the
    head's width at the eyes (temple to temple) and its depth at the nose
    (tip to the back of the head) scale the face across."""
    me = obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    H, floor = body.height, body.floor
    ph = photos["front"]
    m = marks.get("front", {})
    f = {k: ph.f_of_px(m[k]) for k in ("chin", "mouth", "eyes", "skull") if k in m}
    lm = {"sole": floor}
    if not {"mouth", "eyes"} <= set(f):
        return lm
    f_nose = f["mouth"] + (f["eyes"] - f["mouth"]) * 0.45
    lo, hi = floor + (f["mouth"] - 0.01) * H, floor + (f["eyes"] + 0.01) * H
    face = co[(co[:, 2] > lo) & (co[:, 2] < hi) & (np.abs(co[:, 0]) < 0.03)]
    if len(face) == 0:
        return lm
    nose = face[np.argmin(face[:, 1])]
    shift = nose[2] - (floor + f_nose * H)
    for k, v in f.items():
        lm[k] = floor + v * H + shift
    at_eyes = co[(np.abs(co[:, 2] - lm["eyes"]) < 0.012) & (np.abs(co[:, 0]) < 0.14)]
    if len(at_eyes):
        lm["ear_x"] = (float(at_eyes[:, 0].min()), float(at_eyes[:, 0].max()))
    at_nose = co[(np.abs(co[:, 2] - nose[2]) < 0.012) & (np.abs(co[:, 0]) < 0.1)]
    if len(at_nose):
        lm["head_y"] = (float(at_nose[:, 1].min()), float(at_nose[:, 1].max()))
    lm["nose"] = [round(float(x), 4) for x in nose]
    lm["shift"] = round(float(shift), 4)
    return lm


ARM_PARTS = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")


def split_arms(obj, photos, body, margin=0.012):
    """The AI's shape is one skin: weights carried from the nearest body
    point let the shirt's side, the lungi by the hands and the gamchha on
    the chest follow an arm (a web of cloth when he waves or holds the
    handlebar). At each height where the front photo shows the arms apart
    from the body, a point inside the body's span loses its arm weights and
    a point outside it keeps only them. Returns how many points changed."""
    ph = photos["front"]
    names = {g.index: g.name.lower() for g in obj.vertex_groups}
    arm = {i for i, n in names.items() if any(w in n for w in ARM_PARTS)}
    mw = obj.matrix_world
    changed = 0
    for v in obj.data.vertices:
        p = mw @ v.co
        f = (p.z - body.floor) / body.height
        r = ph.row(f)
        if not r or len(r.get("spans", [])) < 3:
            continue
        spans = r["spans"]
        trunk = min(spans, key=lambda s: abs((s[0] + s[1]) / 2.0))
        # Facing the camera, his left (+x) is on the photo's right, so the
        # spans (from the photo's middle) are in the model's x.
        x0, x1 = trunk[0] * body.height, trunk[1] * body.height
        inside = x0 + margin < p.x < x1 - margin
        outside = p.x < x0 - margin or p.x > x1 + margin
        if not (inside or outside):
            continue
        ws = {g.group: g.weight for g in v.groups if g.weight > 0}
        keep = {k: w for k, w in ws.items() if (k in arm) == outside}
        if not keep or len(keep) == len(ws):
            continue
        total = sum(keep.values())
        for k in ws:
            if k in keep:
                obj.vertex_groups[k].add([v.index], keep[k] / total, "REPLACE")
            else:
                obj.vertex_groups[k].remove([v.index])
        changed += 1
    return changed


def vertex_visibility(obj):
    """For each vertex, whether each photo's camera sees it (1) or another
    part of him is in the way (0): front from -Y, back from +Y, the side
    from its own side (+X, or -X for his right, mirrored)."""
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(obj, deps)
    mw = obj.matrix_world
    nm = mw.to_3x3()
    n = len(obj.data.vertices)
    vis = {"front": np.ones(n), "back": np.ones(n), "side": np.ones(n)}
    for v in obj.data.vertices:
        p = mw @ v.co
        nrm = (nm @ v.normal).normalized()
        for view, d in (("front", Vector((0, -1, 0))), ("back", Vector((0, 1, 0))),
                        ("side", Vector((1, 0, 0)) if nrm.x >= 0 else Vector((-1, 0, 0)))):
            hit = tree.ray_cast(p + nrm * 0.003 + d * 0.003, d)
            if hit[0] is not None:
                vis[view][v.index] = 0.0
    return vis


def ensure_uv(obj):
    if obj.data.uv_layers:
        return
    bpy.context.view_layer.objects.active = obj
    for ob in bpy.context.view_layer.objects:
        ob.select_set(ob == obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def paint(obj, mapping, photos, size, arm_fix, roughness=0.8, base=None, side_mirror_above=None, skin_below=None,
          visibility=None):
    """Paints obj's texture from the photos (see the module's notes). On the
    arms and legs below skin_below (a height), only skin-coloured pixels are
    taken: where a view
    sees the shirt, the lungi or the gamchha in front of an arm or a leg (the
    inside of the arm, the palm against the lungi, a calf behind the hem),
    that view is left out, and the texel is filled from its neighbours."""
    ensure_uv(obj)
    mesh = obj.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers.active.data
    mw = obj.matrix_world
    nm = mw.to_3x3()
    co = np.array([tuple(mw @ v.co) for v in mesh.vertices])
    nr = np.array([tuple((nm @ v.normal).normalized()) for v in mesh.vertices])
    limb = None
    if skin_below is not None:
        # Arms and legs, by the bone that moves each vertex most.
        names = {g.index: g.name.lower() for g in obj.vertex_groups}
        limb = np.zeros(len(mesh.vertices), dtype=np.float32)
        for v in mesh.vertices:
            best, w = "", 0.0
            for g in v.groups:
                if g.weight > w:
                    best, w = names.get(g.group, ""), g.weight
            if any(k in best for k in clothes.ARM_WORDS + clothes.LEG_WORDS):
                limb[v.index] = 1.0
    img = np.zeros((size, size, 3), dtype=np.float32)
    have = np.zeros((size, size), dtype=bool)
    # Limb texels no photo shows as skin (a palm against the lungi, a knee
    # under it), and limb texels that took a photo's skin.
    limb_empty = np.zeros((size, size), dtype=bool)
    limb_done = np.zeros((size, size), dtype=bool)
    if base is not None:
        img[:] = base
    for tri in mesh.loop_triangles:
        uv = np.array([tuple(uvl[l].uv) for l in tri.loops]) * size
        vi = list(tri.vertices)
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, size - 1), min(y1, size - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        p = np.stack([gx.ravel(), gy.ravel()], -1)
        a, b, c = uv
        v0, v1 = b - a, c - a
        d = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(d) < 1e-12:
            continue
        w1 = ((p[:, 0] - a[0]) * v1[1] - v1[0] * (p[:, 1] - a[1])) / d
        w2 = (v0[0] * (p[:, 1] - a[1]) - (p[:, 0] - a[0]) * v0[1]) / d
        w0 = 1 - w1 - w2
        inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not inside.any():
            continue
        w = np.stack([w0, w1, w2], -1)[inside]
        pos = w @ co[vi]
        nrm = w @ nr[vi]
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
        tx = p[inside, 0].astype(int)
        ty = p[inside, 1].astype(int)
        only_skin = None
        if limb is not None:
            # Below the chin the body shows only skin (the clothes cover the
            # rest): no cloth colour in its texture, so none bleeds into a
            # hand or a foot when the texture is seen small.
            only_skin = pos[:, 2] < skin_below
        vis = None
        if visibility is not None:
            vis = {view: w @ v[vi] for view, v in visibility.items()}
        col, wsum = colour_at(pos, nrm, mapping, photos, arm_fix, side_mirror_above, only_skin, vis)
        ok = wsum > 1e-3
        img[ty[ok], tx[ok]] = col[ok]
        have[ty[ok], tx[ok]] = True
        if only_skin is not None:
            limb_empty[ty[only_skin & ~ok], tx[only_skin & ~ok]] = True
            limb_done[ty[only_skin & ok], tx[only_skin & ok]] = True
    limb_empty &= ~have
    if base is not None and limb_empty.any() and limb_done.any():
        # The model's own skin there, in the photos' skin colour: never the
        # neighbours' colours, which may be the lungi's under the cloth.
        gain = img[limb_done].mean(0) / np.maximum(base[limb_done].mean(0), 1e-3)
        img[limb_empty] = np.clip(base[limb_empty] * gain, 0, 1)
        have |= limb_empty
    if base is None and have.any():
        img[~have] = img[have].mean(0)
    # Fill what no photo saw (and the seams) from its neighbours.
    for _ in range(24 if visibility is not None else 8):
        grow = ~have & (np.roll(have, 1, 0) | np.roll(have, -1, 0) | np.roll(have, 1, 1) | np.roll(have, -1, 1))
        if not grow.any():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(have.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            hv = np.roll(np.roll(have, dy, 0), dx, 1)
            acc += np.roll(np.roll(img, dy, 0), dx, 1) * hv[..., None]
            cnt += hv
        img[grow] = acc[grow] / np.maximum(cnt[grow], 1)[:, None]
        have |= grow
    out = bpy.data.images.new(obj.name + "_photo", size, size)
    rgba = np.concatenate([img, np.ones((size, size, 1), dtype=np.float32)], -1)
    out.pixels[:] = rgba.ravel()
    out.pack()
    mat = bpy.data.materials.new(obj.name + "_photo")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = out
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    mesh.materials.clear()
    mesh.materials.append(mat)
    return int(have.sum())


def colour_at(pos, nrm, mapping, photos, arm_fix, side_mirror_above, only_skin=None, vis=None):
    """The colour at model points (n, 3) with normals, from the photos."""
    n = pos.shape[0]
    acc = np.zeros((n, 3), dtype=np.float32)
    wsum = np.zeros(n, dtype=np.float32)
    views = {"front": np.clip(-nrm[:, 1], 0, 1) ** 2, "back": np.clip(nrm[:, 1], 0, 1) ** 2}
    # The side photo shows his left (+X); his right side only from it above
    # the chin (the head is near enough the same both sides).
    side_w = np.clip(nrm[:, 0], 0, 1) ** 2
    if side_mirror_above is not None:
        right = np.clip(-nrm[:, 0], 0, 1) ** 2 * (pos[:, 2] > side_mirror_above)
        side_w = side_w + right
    views["side"] = side_w
    for view, wv in views.items():
        if view not in photos or not wv.any():
            continue
        shift = arm_fix(view, pos) if arm_fix else None
        xs, ys = mapping.to_px(view, pos, shift)
        col, ok = photos[view].sample(xs, ys)
        wv = wv * ok
        if only_skin is not None:
            wv = wv * np.where(only_skin, skin_like(col), 1.0)
        if vis is not None and view in vis:
            # Hidden from that camera behind another part (an arm before the
            # body, the gamchha before the shirt): not that photo's colour.
            wv = wv * vis[view]
        acc += col * wv[:, None]
        wsum += wv
    col = acc / np.maximum(wsum, 1e-6)[:, None]
    return col, wsum


def skin_like(col):
    """Skin (brown, not as bright and strong as the orange shirt) or deep
    shadow, by colour: measured on Rahim's photos, 99% of the forearms pass
    and 13% of the shirt."""
    mx = col.max(1)
    ch = mx - col.min(1)
    r, g, b = col[:, 0], col[:, 1], col[:, 2]
    h = np.where(mx == r, ((g - b) / (ch + 1e-6)) % 6, np.where(mx == g, (b - r) / (ch + 1e-6) + 2, (r - g) / (ch + 1e-6) + 4)) * 60.0
    skin = (h >= 14) & (h <= 34) & (ch < 0.48) & (mx < 0.92)
    # Deep shadow on skin is still warm: a dark blue or green is the lungi.
    shadow = (mx < 0.25) & (r >= b) & (r >= g * 0.95)
    return (skin | shadow).astype(np.float32)


def arm_fixer(body, mapping, photos, leg_top=None):
    """Moves the model's arms and legs onto the photo's sideways: at each
    height, a limb's middle in the model against the middle of the same
    limb's span in the photo (arms: the outer spans where the row has three
    or more; legs: the two spans below the lungi). In arrays: it runs for
    every texel."""
    H = mapping.height
    step = 0.02
    zs = np.array([c.z for c in body.co])
    kmax = int(np.ceil(zs.max() / step)) + 2

    def mids_of(pick):
        out = {}
        for s in (1, -1):
            acc = np.zeros(kmax)
            cnt = np.zeros(kmax)
            for i, c in enumerate(body.co):
                if pick(i, c) and (c.x > 0) == (s > 0):
                    k = int(round(c.z / step))
                    if 0 <= k < kmax:
                        acc[k] += c.x
                        cnt[k] += 1
            m = np.full(kmax, np.nan)
            m[cnt > 0] = acc[cnt > 0] / cnt[cnt > 0]
            out[s] = m
        return out

    arm_mids = mids_of(lambda i, c: body.is_arm(i) and "clavicle" not in body.top_group[i])
    top = leg_top if leg_top is not None else body.floor + body.height * 0.2
    leg_mids = mids_of(lambda i, c: body.is_leg(i) and c.z < top)
    spans = {}
    for view in ("front", "back"):
        ph = photos.get(view)
        if ph is None:
            continue
        n = len(ph.rows)
        al, ar, ll, lr = (np.full(n, np.nan) for _ in range(4))
        for i, r in enumerate(ph.rows):
            if not r:
                continue
            sp = r["spans"]
            if len(sp) >= 3:
                al[i] = (sp[0][0] + sp[0][1]) / 2.0 * ph.hpx
                ar[i] = (sp[-1][0] + sp[-1][1]) / 2.0 * ph.hpx
            if len(sp) == 2:
                ll[i] = (sp[0][0] + sp[0][1]) / 2.0 * ph.hpx
                lr[i] = (sp[-1][0] + sp[-1][1]) / 2.0 * ph.hpx
        spans[view] = (al, ar, ll, lr)

    def fix(view, pos):
        if view not in spans:
            return None
        ph = photos[view]
        sign = 1.0 if view == "front" else -1.0
        x, z = pos[:, 0], pos[:, 2]
        s = np.where(x > 0, 1, -1)
        k = np.clip(np.round(z / step).astype(int), 0, kmax - 1)
        fs = mapping.f(view, z)
        ri = np.clip(np.round(fs * (len(ph.rows) - 1)).astype(int), 0, len(ph.rows) - 1)
        al, ar, ll, lr = spans[view]
        out = np.zeros(pos.shape[0], dtype=np.float32)
        for mids, left, right, reach, below in ((arm_mids, al, ar, 0.06, None), (leg_mids, ll, lr, 0.07, top)):
            mm = np.where(s > 0, mids[1][k], mids[-1][k])
            near = ~np.isnan(mm) & (np.abs(x - np.nan_to_num(mm)) < reach)
            if below is not None:
                near &= z < below
            # The photo's span on the limb's own side.
            photo_mid = np.where(s * sign > 0, right[ri], left[ri])
            ok = near & ~np.isnan(photo_mid) & (out == 0)
            out[ok] = sign * photo_mid[ok] - mm[ok] / H * ph.hpx
        return out
    return fix


def hair_cap(body, lm, spec):
    """His own hair: the head's surface above the brows (and behind, down
    to the ears), lifted off it, fuller on top, a little uneven: painted
    from the photos it shows his curls and grey."""
    eyes = lm.get("eyes", body.floor + body.height * 0.93)
    mouth = lm.get("mouth", eyes - 0.07)
    src = body.obj
    deps = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(src.evaluated_get(deps))
    mesh.transform(src.matrix_world)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    bm.verts.ensure_lookup_table()
    face_y = min(c.y for c in body.co) + 0.06
    # Behind the ears: the hair comes down to the nape there; beside and
    # over them it stops above them.
    ear_ys = [body.co[i].y for i in range(len(body.co)) if body.top_group[i] == "ears"]
    ear_back = (max(ear_ys) + 0.008) if ear_ys else 0.02
    ear_top = max([body.co[i].z for i in range(len(body.co)) if body.top_group[i] == "ears"] or [eyes])
    keep = set()
    for v in bm.verts:
        g = body.top_group[v.index] if v.index < len(body.top_group) else ""
        if g not in ("head", "scalp"):
            continue
        c = v.co
        front = c.y < face_y
        if (c.z > eyes + spec.get("brow", 0.035)) or (not front and c.z > ear_top + 0.005) \
                or (c.y > ear_back and c.z > mouth - 0.01):
            keep.add(v.index)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    bm.normal_update()
    rnd = __import__("random").Random(4)
    for v in bm.verts:
        up = max(0.0, min(1.0, (v.co.z - eyes) / 0.12))
        v.co += v.normal * (spec.get("lift", 0.01) + spec.get("volume", 0.022) * up + 0.004 * rnd.random())
    mat = bpy.data.materials.new("hair_cap")
    obj = clothes.new_object("hair", bm, mat)
    clothes.bind(obj, body.obj)
    return obj
