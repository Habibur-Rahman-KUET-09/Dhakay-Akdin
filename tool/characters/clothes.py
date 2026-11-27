"""Dhaka clothes made to a MakeHuman body, in Blender (no clothes asset
has them): a lungi (a tube of checked cloth from the waist), a half-sleeved
shirt (the body's own surface from the hips to the neck and half way down
the upper arms, lifted off the skin), a gamchha over one shoulder (a
red-and-white checked strip), plastic sandals. Each is weighted from the
body's bones, so it moves with the rig.

All sizes in metres; Blender is Z up and the body faces -Y."""
import math
import random

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ARM_WORDS = ("arm", "hand", "finger", "thumb", "index", "middle", "ring", "pinky", "clavicle", "shoulder", "elbow", "wrist")
LEG_WORDS = ("thigh", "calf", "leg", "foot", "toe", "knee", "shin", "ball")


# --- Looking at the body ----------------------------------------------------------


class Body:
    """The evaluated body (targets and the mask applied), its bones' weights
    per vertex, a tree to find the skin from outside."""

    def __init__(self, obj):
        self.obj = obj
        deps = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        self.co = [obj.matrix_world @ v.co for v in mesh.vertices]
        self.normals = [(obj.matrix_world.to_3x3() @ v.normal).normalized() for v in mesh.vertices]
        names = {g.index: g.name for g in obj.vertex_groups}
        self.top_group = []
        for v in mesh.vertices:
            best, w = "", 0.0
            for g in v.groups:
                n = names.get(g.group, "")
                if g.weight > w and not n.startswith(("body", "helper", "joint", "Mid", "Left", "Right")):
                    best, w = n, g.weight
            self.top_group.append(best.lower())
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.transform(obj.matrix_world)
        self.tree = BVHTree.FromBMesh(bm)
        bm.free()
        ev.to_mesh_clear()
        zs = [c.z for c in self.co]
        self.height = max(zs) - min(zs)
        self.floor = min(zs)

    def is_arm(self, i):
        return any(w in self.top_group[i] for w in ARM_WORDS)

    def is_leg(self, i):
        return any(w in self.top_group[i] for w in LEG_WORDS)

    def at(self, frac):
        return self.floor + self.height * frac


# --- Cloth pictures -----------------------------------------------------------------


def checked_image(name, size, colours, stripes, seed=1):
    """A woven check (gamchha, lungi): bands across and along of the given
    colours, mixed where they cross, a little uneven like hand-loomed cloth."""
    rnd = random.Random(seed)
    img = bpy.data.images.new(name, size, size)
    bands = []
    for k in range(stripes):
        bands.append(colours[k % len(colours)])
    px = [0.0] * (size * size * 4)
    for y in range(size):
        by = bands[(y * stripes) // size]
        for x in range(size):
            bx = bands[(x * stripes) // size]
            n = 0.94 + 0.06 * rnd.random()
            # A thread texture: every other line a shade darker.
            t = 0.96 if (x + y) % 2 else 1.0
            i = (y * size + x) * 4
            for k in range(3):
                px[i + k] = (by[k] * 0.5 + bx[k] * 0.5) * n * t
            px[i + 3] = 1.0
    img.pixels[:] = px
    img.pack()
    return img


def plain_image(name, size, colour, seed=2):
    """Plain cloth, faded and a little uneven (washed many times)."""
    rnd = random.Random(seed)
    img = bpy.data.images.new(name, size, size)
    px = [0.0] * (size * size * 4)
    for y in range(size):
        for x in range(size):
            n = 0.9 + 0.1 * rnd.random()
            t = 0.97 if (x // 2 + y // 2) % 2 else 1.0
            i = (y * size + x) * 4
            for k in range(3):
                px[i + k] = colour[k] * n * t
            px[i + 3] = 1.0
    img.pixels[:] = px
    img.pack()
    return img


def cloth_material(name, img, roughness=0.85):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.2
    if "Sheen Weight" in bsdf.inputs:
        bsdf.inputs["Sheen Weight"].default_value = 0.3
    return m


def hex_colour(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    # sRGB to linear, as image pixels are.
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


# --- Making a garment move with the body -------------------------------------------------


def bind(garment, body_obj):
    """Weights from the body's nearest skin, then the same armature."""
    for g in body_obj.vertex_groups:
        if garment.vertex_groups.get(g.name) is None:
            garment.vertex_groups.new(name=g.name)
    dt = garment.modifiers.new("weights", "DATA_TRANSFER")
    dt.object = body_obj
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    garment.select_set(True)
    bpy.context.view_layer.objects.active = garment
    bpy.ops.object.datalayout_transfer(modifier=dt.name)
    bpy.ops.object.modifier_apply(modifier=dt.name)
    rig = body_obj.parent if body_obj.parent and body_obj.parent.type == "ARMATURE" else None
    if rig is not None:
        garment.parent = rig
        am = garment.modifiers.new("rig", "ARMATURE")
        am.object = rig


def new_object(name, bm, material):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


# --- The lungi --------------------------------------------------------------------------


def lungi(body, spec):
    """A tube from the waist to the shins, round both legs, a little loose
    and wider at the hem, the cloth checked."""
    top = body.at(spec.get("top", 0.58))
    bottom = body.at(spec.get("bottom", 0.16))
    rings, sides = 16, 40
    ease = spec.get("ease", 0.018)
    flare = spec.get("flare", 0.035)
    profile = []
    for r in range(rings + 1):
        z = top + (bottom - top) * r / rings
        pts = [c for i, c in enumerate(body.co) if abs(c.z - z) < 0.02 and not body.is_arm(i)]
        if not pts:
            pts = [Vector((0, 0, z))]
        cx = sum(p.x for p in pts) / len(pts)
        cy = sum(p.y for p in pts) / len(pts)
        radii = []
        for s in range(sides):
            a = s * math.tau / sides
            d = Vector((math.cos(a), math.sin(a)))
            far = max((Vector((p.x - cx, p.y - cy)).dot(d) for p in pts), default=0.12)
            radii.append(far)
        profile.append((z, cx, cy, radii))
    # Below the knees the legs part, but the lungi hangs straight: never
    # narrower than the ring above it.
    for r in range(1, len(profile)):
        z, cx, cy, radii = profile[r]
        above = profile[r - 1][3]
        profile[r] = (z, cx, cy, [max(radii[s], above[s] * 0.985) for s in range(sides)])
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    verts = []
    for r, (z, cx, cy, radii) in enumerate(profile):
        t = r / rings
        row = []
        for s in range(sides):
            a = s * math.tau / sides
            fold = 0.006 * math.sin(a * 7 + r * 0.7)
            rad = radii[s] + ease + flare * t * t + fold
            row.append(bm.verts.new((cx + math.cos(a) * rad, cy + math.sin(a) * rad, z)))
        verts.append(row)
    for r in range(rings):
        for s in range(sides):
            s2 = (s + 1) % sides
            f = bm.faces.new((verts[r][s], verts[r][s2], verts[r + 1][s2], verts[r + 1][s]))
            for loop, (uu, vv) in zip(f.loops, [(s, r), (s + 1, r), (s + 1, r + 1), (s, r + 1)]):
                loop[uv].uv = (uu / sides * spec.get("repeat", 3.0), 1.0 - vv / rings * 1.5)
    bm.normal_update()
    img = checked_image("lungi_check", 256, [hex_colour(c) for c in spec.get("colours", ["2D5D8A", "1F7A50", "2D5D8A", "D9D4C7"])], spec.get("stripes", 12))
    obj = new_object("lungi", bm, cloth_material("lungi", img, 0.9))
    bind(obj, body.obj)
    return obj


# --- The shirt -----------------------------------------------------------------------------


def shirt(body, spec):
    """The body's own surface from the hips to the neck and part way down
    the upper arms, lifted off the skin: a loose, half-sleeved shirt."""
    bottom = body.at(spec.get("bottom", 0.53))
    neck = body.at(spec.get("neck", 0.83))
    sleeve = spec.get("sleeve", 0.45)
    # How far out the shoulders go (the sleeve ends `sleeve` of the way to the hand).
    xs = [abs(c.x) for i, c in enumerate(body.co) if body.is_arm(i)]
    arm_reach = max(xs) if xs else 0.6
    shoulder_x = body.height * 0.11
    end_x = shoulder_x + (arm_reach - shoulder_x) * sleeve * 0.5
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
        if c.z < bottom or c.z > neck:
            continue
        if body.is_leg(v.index):
            continue
        if body.is_arm(v.index) and abs(c.x) > end_x:
            continue
        keep.add(v.index)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context="VERTS")
    bm.normal_update()
    # Loose: out from the skin, more at the belly and back, and the hem hangs.
    for v in bm.verts:
        lift = spec.get("lift", 0.012)
        if v.co.z < bottom + 0.12:
            lift += 0.01 * (1.0 - (v.co.z - bottom) / 0.12)
        v.co += v.normal * lift
    img = plain_image("shirt_cloth", 128, hex_colour(spec.get("colour", "C9783A")))
    obj = new_object("shirt", bm, cloth_material("shirt", img, 0.88))
    # Body UVs are kept (plain cloth shows no seams).
    bind(obj, body.obj)
    return obj


# --- The gamchha -------------------------------------------------------------------------


def gamchha(body, spec):
    """A red-and-white checked strip over one shoulder: down the chest in
    front, over the top of the shoulder, down the back."""
    side = spec.get("side", -1)
    h = body.height
    path = [(0.10, -1.0, 0.60), (0.11, -1.0, 0.70), (0.12, -0.6, 0.79), (0.13, 0.0, 0.82),
            (0.12, 0.6, 0.79), (0.11, 1.0, 0.70), (0.10, 1.0, 0.60)]
    width = spec.get("width", 0.13)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rows = []
    centre_y = sum(c.y for c in body.co) / len(body.co)
    for k, (fx, fy, fz) in enumerate(path):
        x = side * h * fx
        z = body.floor + h * fz
        row = []
        for edge in (-0.5, 0.5):
            p = Vector((x + side * edge * width * 0.6, centre_y + fy * 0.3, z))
            # Onto the skin from outside, then a little off it.
            hit, normal, _i, _d = body.tree.find_nearest(p)
            if hit is None:
                hit, normal = p, Vector((0, fy, 0))
            row.append(bm.verts.new(hit + normal * 0.02))
        rows.append(row)
    for k in range(len(rows) - 1):
        f = bm.faces.new((rows[k][0], rows[k][1], rows[k + 1][1], rows[k + 1][0]))
        for loop, (uu, vv) in zip(f.loops, [(0, k), (1, k), (1, k + 1), (0, k + 1)]):
            loop[uv].uv = (uu, vv / (len(rows) - 1) * 4.0)
    bm.normal_update()
    sol = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    for v in [e for e in sol["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co += v.normal * -0.004
    img = checked_image("gamchha_check", 128, [hex_colour("C62828"), hex_colour("F2EFE6"), hex_colour("C62828"), hex_colour("2E7D32")], 8, 3)
    obj = new_object("gamchha", bm, cloth_material("gamchha", img, 0.92))
    bind(obj, body.obj)
    return obj


# --- Sandals ---------------------------------------------------------------------------------


def sandals(body, spec):
    """A rubber sole under each foot and a strap across it."""
    colour = spec.get("colour", "2B4C7E")
    bm = bmesh.new()
    for side in (-1, 1):
        pts = [c for i, c in enumerate(body.co) if c.z < body.floor + 0.06 and c.x * side > 0.02]
        if not pts:
            continue
        x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
        y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
        geom = bmesh.ops.create_cube(bm, size=1.0)
        for v in geom["verts"]:
            v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0 + 0.02), (y0 + y1) / 2 + v.co.y * (y1 - y0 + 0.02), body.floor + 0.006 + v.co.z * 0.014))
        strap = bmesh.ops.create_cube(bm, size=1.0)
        for v in strap["verts"]:
            v.co = Vector(((x0 + x1) / 2 + v.co.x * (x1 - x0 + 0.01), y0 + (y1 - y0) * 0.3 + v.co.y * 0.03, body.floor + 0.045 + v.co.z * 0.012))
    img = plain_image("sandal_rubber", 32, hex_colour(colour), 5)
    obj = new_object("sandals", bm, cloth_material("sandals", img, 0.7))
    bind(obj, body.obj)
    return obj


MAKERS = {"lungi": lungi, "shirt": shirt, "gamchha": gamchha, "sandals": sandals}


def dress(body_obj, outfit, report):
    body = Body(body_obj)
    report["body"] = {"height": round(body.height, 3), "groups": sorted(set(body.top_group))[:80]}
    made = {}
    for name, spec in outfit.items():
        maker = MAKERS.get(name)
        if maker is None:
            report["errors"].append("no maker for %s" % name)
            continue
        try:
            made[name] = maker(body, spec)
        except Exception as e:  # one garment failing should not lose the rest
            import traceback
            report["errors"].append("%s: %s" % (name, traceback.format_exc()[-600:]))
    return made
