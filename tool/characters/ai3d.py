"""A character's shape and texture from their photos by an image-to-3D
model on a Hugging Face Space (free GPU time; an HF_TOKEN in the
environment gives more of it).

    python3 tool/characters/ai3d.py api <space> [<space> ...]
        prints what each Space takes (no GPU used)
    python3 tool/characters/ai3d.py run <space> <name> <out dir> [key=value ...]
        sends tool/characters/ref/<name>_front.png (and the side and back,
        where the Space takes several views) and saves <out dir>/<name>.ai.glb
"""
import json
import os
import shutil
import sys

from gradio_client import Client, handle_file

HERE = os.path.dirname(os.path.abspath(__file__))


def client(space):
    token = os.environ.get("HF_TOKEN") or None
    return Client(space, hf_token=token, verbose=False)


def api(spaces):
    for s in spaces:
        print("=" * 30, s)
        try:
            c = client(s)
            info = c.view_api(print_info=False, return_format="dict")
            for name, ep in info.get("named_endpoints", {}).items():
                params = [(p.get("parameter_name"), p.get("python_type", {}).get("type"), p.get("parameter_default"))
                          for p in ep.get("parameters", [])]
                rets = [r.get("python_type", {}).get("type") for r in ep.get("returns", [])]
                print(name, json.dumps(params, default=str)[:900], "->", rets)
        except Exception as e:
            print("failed:", repr(e)[:400])


def first_file(x):
    """The first path to a .glb (or any file) in a Space's reply."""
    if isinstance(x, str) and os.path.exists(x):
        return x
    if isinstance(x, dict):
        for k in ("value", "path", "name"):
            if k in x:
                f = first_file(x[k])
                if f:
                    return f
    if isinstance(x, (list, tuple)):
        found = [first_file(v) for v in x]
        found = [f for f in found if f]
        glb = [f for f in found if f.endswith((".glb", ".gltf"))]
        return (glb or found or [None])[0]
    return None


def run(space, name, out, extra):
    ref = lambda v: os.path.join(HERE, "ref", "%s_%s.png" % (name, v))
    c = client(space)
    kwargs = {}
    api_name = None
    for kv in extra:
        k, v = kv.split("=", 1)
        if k == "api_name":
            api_name = v
            continue
        # file:front -> that photo; numbers and true/false as such.
        if v.startswith("file:"):
            kwargs[k] = handle_file(ref(v[5:]))
        elif v in ("true", "false"):
            kwargs[k] = v == "true"
        else:
            try:
                kwargs[k] = int(v)
            except ValueError:
                try:
                    kwargs[k] = float(v)
                except ValueError:
                    kwargs[k] = v
    print("calling", space, api_name, {k: (str(v)[:60]) for k, v in kwargs.items()})
    reply = c.predict(api_name=api_name, **kwargs)
    print("reply:", str(reply)[:1500])
    f = first_file(reply)
    if not f:
        sys.exit("no file in the reply")
    os.makedirs(out, exist_ok=True)
    dest = os.path.join(out, "%s.ai%s" % (name, os.path.splitext(f)[1] or ".glb"))
    shutil.copy(f, dest)
    print("saved", dest, os.path.getsize(dest))


if __name__ == "__main__":
    if sys.argv[1] == "api":
        api(sys.argv[2:])
    else:
        run(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:])
