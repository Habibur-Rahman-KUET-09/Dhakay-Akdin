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
    # Over the shoulder: between the top front and top back rows, raised.
    if front_rows and back_rows:
        a, b = front_rows[-1], back_rows[0]
        mid = [(a[i] + b[i]) / 2 + Vector((0, 0, 0.05)) for i in range(2)]
        rows = front_rows + [mid] + back_rows
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


def paint(obj, mapping, photos, size, arm_fix, roughness=0.8, base=None, side_mirror_above=None):
    """Paints obj's texture from the photos (see the module's notes)."""
    ensure_uv(obj)
    mesh = obj.data
    mesh.calc_loop_triangles()
    uvl = mesh.uv_layers.active.data
    mw = obj.matrix_world
    nm = mw.to_3x3()
    co = np.array([tuple(mw @ v.co) for v in mesh.vertices])
    nr = np.array([tuple((nm @ v.normal).normalized()) for v in mesh.vertices])
    img = np.zeros((size, size, 3), dtype=np.float32)
    have = np.zeros((size, size), dtype=bool)
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
        col, wsum = colour_at(pos, nrm, mapping, photos, arm_fix, side_mirror_above)
        ok = wsum > 1e-3
        img[ty[ok], tx[ok]] = col[ok]
        have[ty[ok], tx[ok]] = True
    if base is None and have.any():
        img[~have] = img[have].mean(0)
    # Fill what no photo saw (and the seams) from its neighbours.
    for _ in range(6):
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


def colour_at(pos, nrm, mapping, photos, arm_fix, side_mirror_above):
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
        acc += col * wv[:, None]
        wsum += wv
    col = acc / np.maximum(wsum, 1e-6)[:, None]
    return col, wsum


def arm_fixer(body, mapping, photos):
    """Moves the model's arms onto the photo's arms sideways: at each height,
    the model arm's middle against the outer span's middle in the photo
    (all in arrays: it runs for every texel)."""
    H = mapping.height
    step = 0.02
    zs = np.array([c.z for c in body.co])
    kmax = int(np.ceil(zs.max() / step)) + 2
    mids = {}
    for s in (1, -1):
        acc = np.zeros(kmax)
        cnt = np.zeros(kmax)
        for i, c in enumerate(body.co):
            if body.is_arm(i) and "clavicle" not in body.top_group[i] and (c.x > 0) == (s > 0):
                k = int(round(c.z / step))
                if 0 <= k < kmax:
                    acc[k] += c.x
                    cnt[k] += 1
        m = np.full(kmax, np.nan)
        m[cnt > 0] = acc[cnt > 0] / cnt[cnt > 0]
        mids[s] = m
    spans = {}
    for view in ("front", "back"):
        ph = photos.get(view)
        if ph is None:
            continue
        left = np.full(len(ph.rows), np.nan)
        right = np.full(len(ph.rows), np.nan)
        for i, r in enumerate(ph.rows):
            if r and len(r["spans"]) >= 3:
                left[i] = (r["spans"][0][0] + r["spans"][0][1]) / 2.0 * ph.hpx
                right[i] = (r["spans"][-1][0] + r["spans"][-1][1]) / 2.0 * ph.hpx
        spans[view] = (left, right)

    def fix(view, pos):
        if view not in spans:
            return None
        ph = photos[view]
        sign = 1.0 if view == "front" else -1.0
        x, z = pos[:, 0], pos[:, 2]
        s = np.where(x > 0, 1, -1)
        k = np.clip(np.round(z / step).astype(int), 0, kmax - 1)
        mm = np.where(s > 0, mids[1][k], mids[-1][k])
        near = ~np.isnan(mm) & (np.abs(x - np.nan_to_num(mm)) < 0.06)
        fs = mapping.f(view, z)
        ri = np.clip(np.round(fs * (len(ph.rows) - 1)).astype(int), 0, len(ph.rows) - 1)
        left, right = spans[view]
        # The photo's outer span on the arm's own side.
        photo_mid = np.where(s * sign > 0, right[ri], left[ri])
        ok = near & ~np.isnan(photo_mid)
        out = np.zeros(pos.shape[0], dtype=np.float32)
        out[ok] = sign * photo_mid[ok] - mm[ok] / H * ph.hpx
        return out
    return fix
