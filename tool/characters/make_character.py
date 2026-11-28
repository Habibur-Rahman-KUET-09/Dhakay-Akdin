"""Makes one of the game's people with MPFB (MakeHuman in Blender, CC0
assets): run by .github/workflows/characters.yml as

    blender -b --python tool/characters/make_character.py -- <name> <out dir>

reading tool/characters/<name>.json. Writes <out>/<name>.glb (rigged, game
materials), <out>/<name>.report.json (what was used, what assets exist)."""
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clothes  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
NAME, OUT = argv[0], argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = json.load(open(os.path.join(HERE, NAME + ".json")))
os.makedirs(OUT, exist_ok=True)
report = {"name": NAME, "picked": {}, "assets": {}, "errors": []}

from bl_ext.user_default.mpfb.services.humanservice import HumanService  # noqa: E402
from bl_ext.user_default.mpfb.services.assetservice import AssetService  # noqa: E402

SUBDIRS = {"skins": "*.mhmat", "eyes": "*.mhclo", "eyebrows": "*.mhclo", "eyelashes": "*.mhclo", "teeth": "*.mhclo",
           "tongue": "*.mhclo", "hair": "*.mhclo", "clothes": "*.mhclo", "proxymeshes": "*.proxy"}
found = {}
for sub, pattern in SUBDIRS.items():
    files = sorted(str(p) for p in AssetService.find_asset_files_matching_pattern(AssetService.get_asset_roots(sub), pattern))
    found[sub] = files
    report["assets"][sub] = [os.path.relpath(f, os.path.dirname(os.path.dirname(f))) for f in files]


def pick(sub, wishes):
    """The first asset whose file name has all the words of a wish, word for
    word ("male" does not match "female")."""
    for words in wishes:
        for f in found.get(sub, []):
            tokens = os.path.splitext(os.path.basename(f))[0].lower().replace("-", "_").split("_")
            whole = os.path.splitext(os.path.basename(f))[0].lower()
            if all(w in tokens or w == whole for w in words):
                return f
    return None


def shrink(img):
    """No bigger than the phone needs (before any work on its pixels)."""
    limit = SPEC.get("max_texture", 1024)
    if img.size[0] > limit or img.size[1] > limit:
        f = limit / max(img.size[0], img.size[1])
        img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))


def tint_images(obj, colour, keep):
    """Recolours an asset's textures toward `colour` (hair dark, a little of
    its own light kept, so it stays hair and not paint)."""
    for slot in obj.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0:
                img = n.image
                shrink(img)
                px = list(img.pixels)
                for i in range(0, len(px), 4):
                    lum = 0.3 * px[i] + 0.59 * px[i + 1] + 0.11 * px[i + 2]
                    for k in range(3):
                        px[i + k] = colour[k] * (1.0 - keep) + lum * keep * colour[k] * 3.0
                img.pixels[:] = px
                img.update()


# An empty scene.
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

human = HumanService.create_human(macro_detail_dict=SPEC["macro"], scale=0.1)
human.name = NAME
try:
    HumanService.add_builtin_rig(human, SPEC.get("rig", "standard.game_engine"))
except Exception as e:  # keep going: a picture without a rig still tells a lot
    report["errors"].append("rig: %r" % e)

skin = pick("skins", SPEC.get("skin", []))
report["picked"]["skin"] = skin
if skin:
    try:
        HumanService.set_character_skin(skin, human, skin_type="GAMEENGINE")
    except Exception as e:
        report["errors"].append("skin: %r" % e)

added = {}
for part, kind in [("eyes", "Eyes"), ("eyebrows", "Eyebrows"), ("eyelashes", "Eyelashes"), ("teeth", "Teeth"),
                   ("tongue", "Tongue"), ("hair", "Hair")]:
    f = pick(part, SPEC.get(part, []))
    report["picked"][part] = f
    if f:
        try:
            added[part] = HumanService.add_mhclo_asset(f, human, asset_type=kind, subdiv_levels=0, material_type="GAMEENGINE")
        except Exception as e:
            report["errors"].append("%s: %r" % (part, e))
def tone_images(obj, factor):
    """Darkens or warms a skin's own textures (multiplies them), keeping
    every pore and shade."""
    done = set()
    for slot in obj.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.name not in done and n.image.size[0] > 0:
                lname = n.image.name.lower()
                if "normal" in lname or "nrm" in lname or "rough" in lname:
                    continue
                done.add(n.image.name)
                img = n.image
                shrink(img)
                px = list(img.pixels)
                for i in range(0, len(px), 4):
                    for k in range(3):
                        px[i + k] = px[i + k] * factor[k]
                img.pixels[:] = px
                img.update()
    return sorted(done)


if SPEC.get("skin_tone") and not SPEC.get("photos"):
    report["toned"] = tone_images(human, SPEC["skin_tone"])

def base_pixels(obj, size):
    """The object's own base colour texture as an array (bottom row first,
    as UVs count), resized; None if it has none."""
    for slot in obj.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0:
                lname = n.image.name.lower()
                if "normal" in lname or "nrm" in lname:
                    continue
                img = n.image.copy()
                img.scale(size, size)
                import numpy as np
                arr = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)[..., :3].copy()
                bpy.data.images.remove(img)
                return arr
    return None


if SPEC.get("photos"):
    import numpy as np
    import photo_fit
    P = SPEC["photos"]
    meas = json.load(open(os.path.join(HERE, "ref", NAME + ".measure.json")))
    photos = {v: photo_fit.Photo(os.path.join(HERE, "ref", "%s_%s.png" % (NAME, v)), meas["views"][v]) for v in ("front", "side", "back")}
    # Brows and lashes are in the photos (painted on the face).
    for part in P.get("drop", ["eyebrows", "eyelashes"]):
        o = added.pop(part, None)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    rig = human.parent
    try:
        photo_fit.pose_arms_down(rig, P.get("arm_out_deg", 7.0))
    except Exception as e:
        report["errors"].append("pose: %r" % e)
    body = clothes.Body(human)
    lm = photo_fit.model_landmarks(body, added.get("eyes"))
    report["landmarks"] = {k: (round(v, 4) if isinstance(v, float) else [round(x, 4) for x in v]) for k, v in lm.items()}
    mapping = photo_fit.Mapping(lm, photos, P["marks"], body.height)
    AI = bool(P.get("ai_mesh"))
    if AI:
        # The AI's shape of him, painted from the photos where each camera
        # sees it, moved by the MakeHuman rig (its weights carried over).
        try:
            ai = photo_fit.ai_body(os.path.join(HERE, "ref", P["ai_mesh"]), body, P.get("ai", {}))
            report["ai_faces"] = len(ai.data.polygons)
            alm = photo_fit.ai_landmarks(ai, body, photos, P["marks"])
            report["ai_landmarks"] = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in alm.items()}
            amap = photo_fit.Mapping({k: v for k, v in alm.items() if k not in ("nose", "shift")}, photos, P["marks"], body.height)
            vis = photo_fit.vertex_visibility(ai)
            report["ai_hidden"] = {k: int((v < 0.5).sum()) for k, v in vis.items()}
            tex = P.get("texture", {"body": 2048})
            report["painted"] = {"ai": photo_fit.paint(ai, amap, photos, tex["body"], None, 0.8,
                                                       side_mirror_above=alm.get("chin", body.floor + body.height * 0.86), visibility=vis)}
            clothes.bind(ai, human)
            report["ai_arm_tubes"] = photo_fit.arm_tubes(ai, human, human.parent)
            report["ai_split_arms"] = photo_fit.split_arms(ai, photos, body)
            report["ai_cut_webs"] = photo_fit.cut_webs(ai, human.parent)
            for o in list(bpy.data.objects):
                if o.type == "MESH" and o != ai:
                    bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            import traceback
            report["errors"].append("ai: %s" % traceback.format_exc()[-900:])
    if not AI:
        made = {}
        for name, maker in (("lungi", lambda: photo_fit.lungi_from_photos(body, mapping, photos, P["lungi"])),
                            ("shirt", lambda: photo_fit.shirt_from_photos(body, mapping, P["shirt"])),
                            ("gamchha", lambda: photo_fit.gamchha_from_photos(body, mapping, photos, P["gamchha"])),
                            ("sandals", lambda: clothes.sandals(body, P.get("sandals", {}))),
                            ("hair", lambda: photo_fit.hair_cap(body, lm, P["hair_cap"]) if P.get("hair_cap") else None)):
            try:
                if name == "hair" and P.get("hair_cap"):
                    old_hair = added.pop("hair", None)
                    if old_hair is not None:
                        bpy.data.objects.remove(old_hair, do_unlink=True)
                obj = maker()
                if obj is not None:
                    made[name] = obj
            except Exception:
                import traceback
                report["errors"].append("%s: %s" % (name, traceback.format_exc()[-700:]))
        report["picked"]["outfit"] = sorted(made)
        mz, pf = mapping.knots["front"]
        try:
            photo_fit.hide_under(human, float(np.interp(P["shirt"]["hem"], pf, mz)), float(np.interp(P["lungi"]["hem"], pf, mz)))
        except Exception as e:
            report["errors"].append("hide: %r" % e)
        # Only his hair stays on the hair cap; the shirt opens at the collar
        # where the photo shows his chest.
        report["trimmed"] = {}
        try:
            if "hair" in made:
                report["trimmed"]["hair"] = photo_fit.trim_by_colour(
                    made["hair"], mapping, photos, photo_fit.hair_like,
                    region=lambda c, n: c[:, 2] < lm["eyes"] + 0.09, side_mirror_above=lm.get("chin"))
            if "shirt" in made:
                chest = float(np.interp(P["shirt"].get("collar_from", 0.7), pf, mz))
                report["trimmed"]["shirt"] = photo_fit.trim_by_colour(
                    made["shirt"], mapping, photos, lambda col: 1.0 - photo_fit.skin_like(col),
                    region=lambda c, n: (c[:, 2] > chest) & (n[:, 1] < -0.2) & (np.abs(c[:, 0]) < body.height * 0.06))
        except Exception:
            import traceback
            report["errors"].append("trim: %s" % traceback.format_exc()[-700:])
        if SPEC.get("skin_tone"):
            report["toned"] = tone_images(human, SPEC["skin_tone"])
        fix = photo_fit.arm_fixer(body, mapping, photos, float(np.interp(P["lungi"]["hem"], pf, mz)))

        tex = P.get("texture", {"body": 2048, "cloth": 1024})
        report["painted"] = {}
        try:
            base = base_pixels(human, tex["body"])
            report["painted"]["body"] = photo_fit.paint(human, mapping, photos, tex["body"], fix, 0.6, base=base, side_mirror_above=lm.get("chin"),
                                                                  skin_below=lm.get("chin") - 0.02 if lm.get("chin") is not None else None)
        except Exception:
            import traceback
            report["errors"].append("paint body: %s" % traceback.format_exc()[-700:])
        for name, o in made.items():
            if name == "sandals":
                continue
            try:
                report["painted"][name] = photo_fit.paint(o, mapping, photos, tex["cloth"], fix if name == "shirt" else None,
                                                          0.9 if name == "hair" else 0.85,
                                                          side_mirror_above=lm.get("chin") if name == "hair" else None)
            except Exception:
                import traceback
                report["errors"].append("paint %s: %s" % (name, traceback.format_exc()[-700:]))
        for part, look in SPEC.get("tint", {}).items():
            if part in added and added[part] is not None:
                tint_images(added[part], look["colour"], look.get("keep", 0.25))
elif SPEC.get("outfit"):
    made = clothes.dress(human, SPEC["outfit"], report)
    report["picked"]["outfit"] = sorted(made)
for part, look in ({} if SPEC.get("photos") else SPEC.get("tint", {})).items():
    if part in added and added[part] is not None:
        tint_images(added[part], look["colour"], look.get("keep", 0.25))
for wishes in SPEC.get("clothes", []):
    f = pick("clothes", [wishes])
    report["picked"].setdefault("clothes", []).append(f)
    if f:
        try:
            HumanService.add_mhclo_asset(f, human, asset_type="Clothes", subdiv_levels=0, material_type="GAMEENGINE")
        except Exception as e:
            report["errors"].append("clothes %s: %r" % (wishes, e))

# Skin and cloth are not wet: rougher, less shine. Textures no bigger
# than the phone needs.
MAX_TEX = SPEC.get("max_texture", 1024)
for m in bpy.data.materials:
    if m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                if not n.inputs["Roughness"].is_linked:
                    n.inputs["Roughness"].default_value = max(n.inputs["Roughness"].default_value, SPEC.get("roughness", 0.62))
                if "Specular IOR Level" in n.inputs and not n.inputs["Specular IOR Level"].is_linked:
                    n.inputs["Specular IOR Level"].default_value = 0.3
for img in bpy.data.images:
    if img.size[0] > MAX_TEX or img.size[1] > MAX_TEX:
        f = MAX_TEX / max(img.size[0], img.size[1])
        img.scale(max(1, int(img.size[0] * f)), max(1, int(img.size[1] * f)))

# Counts, for the phone's sake.
report["meshes"] = {o.name: len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"}
report["materials"] = {m.name: [n.type for n in m.node_tree.nodes] if m.use_nodes else [] for m in bpy.data.materials}

glb = os.path.join(OUT, NAME + ".glb")
try:
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_apply=True, export_animations=False,
                              export_yup=True, export_image_format="JPEG", export_jpeg_quality=82)
    report["glb_bytes"] = os.path.getsize(glb)
except Exception as e:
    report["errors"].append("export: %r" % e)
json.dump(report, open(os.path.join(OUT, NAME + ".report.json"), "w"), indent=1)
print("REPORT", json.dumps({k: report[k] for k in ("picked", "errors", "meshes")}, indent=1))
