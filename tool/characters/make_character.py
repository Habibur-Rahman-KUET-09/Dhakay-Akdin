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
if SPEC.get("outfit"):
    made = clothes.dress(human, SPEC["outfit"], report)
    report["picked"]["outfit"] = sorted(made)
for part, look in SPEC.get("tint", {}).items():
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
