#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Starts a console drawn from a glb (docs/adding-a-console.md): its folder under app/carousel/consoles, with the glb,
its textures as PNG files beside it, its manifest, its scene and its shape, its licence and its credit in the README;
its model in the core's ConsoleVariant. The console has no launch steps yet: it is offered greyed, as coming.

What the files cannot know is printed at the end: the values to measure (the seat, the way in), and the shared files
still to fill (logos, colour, the tests' measured counts).

Usage: scripts/new_console.py <folder> --platform genesis --glb model.glb --version mk-1631 --name "Mega Drive"
    --model-name "Model 2" --licence license.txt [--variant-of megadrive] [--budget 10000] [--changes "..."]

The licence is the one the model was downloaded with (a Sketchfab `license.txt`): it must hold the credit line,
`This work is based on "<title>" (<source>) by <author> licensed under CC-BY-4.0 (...)`.
"""
import argparse
import json
import math
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
CONSOLES = APP / "carousel" / "consoles"
VARIANTS = ROOT / "kotlin/core/src/main/kotlin/app/cartouche/core/library/ConsoleVariant.kt"
VARIANTS_TEST = ROOT / "kotlin/core/src/test/kotlin/app/cartouche/core/library/ConsoleVariantTest.kt"
README = ROOT / "README.md"
CREDIT = re.compile(r'^This work is based on ".+" \((\S+)\) by .+ licensed under CC-BY-4\.0 \(\S+\)$', re.M)
LOGO_SLOTS = ("between-mini", "games-top", "plinth-plate", "rail-tile", "ring-middle")
# The glb's import: the app's unit is 10 cm, no LODs, shadow meshes nor animations, the textures read from the PNG files
# beside it.
GLB_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[params]

nodes/root_scale=10.0
meshes/generate_lods=false
meshes/create_shadow_meshes=false
animation/import=false
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"""
# A texture's import: compressed for the GPU, with mipmaps; a normal map flagged as one.
PNG_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/normal_map={normal}
mipmaps/generate=true
detect_3d/compress_to=1
"""


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    if data[:4] != b"glTF":
        raise SystemExit(f"{path}: not a glb")
    json_length = struct.unpack("<I", data[12:16])[0]
    document = json.loads(data[20:20 + json_length])
    at = 20 + json_length
    binary = data[at + 8:at + 8 + struct.unpack("<I", data[at:at + 4])[0]] if at < len(data) else b""
    return document, binary


def write_glb(path: Path, document: dict, binary: bytes) -> None:
    text = json.dumps(document, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    chunks = struct.pack("<I4s", len(text), b"JSON") + text + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    path.write_bytes(struct.pack("<4sII", b"glTF", 2, 12 + len(chunks)) + chunks)


def triangles(document: dict) -> int:
    accessors = document["accessors"]
    return sum((accessors[p["indices"]] if "indices" in p else accessors[p["attributes"]["POSITION"]])["count"] // 3
               for mesh in document["meshes"] for p in mesh["primitives"] if p.get("mode", 4) == 4)


def unpack_images(document: dict, binary: bytes, glb_folder: Path, folder: Path, name: str) -> tuple[bytes, list[Path]]:
    """Writes each image of the glb as `<name>_<image>.png` in [folder], the glb naming it by its file: those it embeds,
    and those beside it in [glb_folder]; returns the buffer without the embedded images, and the files written."""
    views = document.get("bufferViews", [])
    embedded = {image["bufferView"] for image in document.get("images", []) if "bufferView" in image}
    written = []
    for image in document.get("images", []):
        if "bufferView" not in image:
            source = glb_folder / image["uri"]
            png = folder / f"{name}_{source.name.removeprefix(source.stem.split('_')[0] + '_')}"
            png.write_bytes(source.read_bytes())
            image["uri"] = png.name
            written.append(png)
            continue
        view = views[image.pop("bufferView")]
        stem = image.get("name", f"image{len(written)}").removeprefix(name + "_")
        png = folder / f"{name}_{stem}.png"
        png.write_bytes(binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]])
        image["uri"] = png.name
        written.append(png)
    kept, index, blob = [], {}, bytearray()
    for i, view in enumerate(views):
        if i in embedded:
            continue
        blob += b"\0" * (-len(blob) % 4)
        start = view.get("byteOffset", 0)
        index[i] = len(kept)
        kept.append(dict(view, byteOffset=len(blob)))
        blob += binary[start:start + view["byteLength"]]
    document["bufferViews"] = kept
    for accessor in document.get("accessors", []):
        if "bufferView" in accessor:
            accessor["bufferView"] = index[accessor["bufferView"]]
    if document.get("buffers"):
        document["buffers"][0]["byteLength"] = len(blob)
    return bytes(blob), written


def scene_values(base: str) -> list[str]:
    """The way in and the pose of [base]'s scene, which a variant of it starts from."""
    text = (CONSOLES / base / f"{base}.tscn").read_text()
    return re.findall(r"^(?:way_in|pose) = .*$", text, re.M)


def add_variant_entry(folder: str, platform: str) -> str:
    text = VARIANTS.read_text()
    if f'@SerialName("{folder}")' in text:
        return "already listed"
    entry = f'    @SerialName("{folder}")\n    {folder.upper()}(PlatformId("{platform}"), "{folder}"),\n'
    same = list(re.finditer(rf'    @SerialName\("[^"]+"\)\n    \w+\(PlatformId\("{platform}"\), "[^"]+"\),\n', text))
    at = same[-1].end() if same else text.index("    ;\n")
    VARIANTS.write_text(text[:at] + "\n" + entry + text[at:])
    return "added"


def take_off_awaited(folder: str) -> None:
    text = VARIANTS_TEST.read_text()
    awaited = re.search(r"setOf\(([^)]*)\)", text)
    if awaited and f"ConsoleVariant.{folder.upper()}" in awaited.group(1):
        names = [n.strip() for n in awaited.group(1).split(",") if n.strip() != f"ConsoleVariant.{folder.upper()}"]
        listed = f"setOf({', '.join(names)})" if names else "emptySet<ConsoleVariant>()"
        VARIANTS_TEST.write_text(text[:awaited.start()] + listed + text[awaited.end():])


def add_credit(credit: str) -> None:
    text = README.read_text()
    if credit in text:
        return
    section = text.index("### 3D models")
    last = list(re.finditer(r"^- This work is based on .*$", text[section:text.index("\n### ", section + 1)], re.M))[-1]
    at = section + last.end()
    README.write_text(text[:at] + f"\n- {credit}" + text[at:])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("folder", help="the console's folder name, lower case (`megadrive2`)")
    parser.add_argument("--platform", required=True, help="its platform, a key of app/data/platforms/profiles.json")
    parser.add_argument("--glb", required=True, type=Path, help="its prepared model")
    parser.add_argument("--version", required=True, help="its model code, lower case, hyphens between words")
    parser.add_argument("--name", required=True, help='the console\'s short name ("Mega Drive")')
    parser.add_argument("--model-name", required=True, help='this model\'s name ("Model 2")')
    parser.add_argument("--licence", required=True, type=Path, help="the licence the model was downloaded with")
    parser.add_argument("--changes", default="", help="what was changed from the download, for its licence")
    parser.add_argument("--variant-of", help="the platform's base model folder, for another model of it")
    parser.add_argument("--budget", type=int, help="the most triangles it may draw (its count, rounded up)")
    args = parser.parse_args()

    folder = CONSOLES / args.folder
    if not re.fullmatch(r"[a-z0-9_]+", args.folder) or folder.exists():
        parser.error(f"{args.folder}: a new folder name in lower case, digits and underscores")
    if args.platform not in json.loads((APP / "data/platforms/profiles.json").read_text()):
        parser.error(f"{args.platform}: no such platform in app/data/platforms/profiles.json")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", args.version):
        parser.error(f"{args.version}: a model code in lower case, hyphens between words")
    licence = args.licence.read_text()
    credit = CREDIT.search(licence)
    if not credit:
        parser.error(f"{args.licence}: no CC-BY-4.0 credit line")
    base = args.variant_of
    if base and not (CONSOLES / base / "console.tres").is_file():
        parser.error(f"{base}: no such console folder")

    document, binary = read_glb(args.glb)
    count = triangles(document)
    budget = args.budget or math.ceil(count / 1000) * 1000
    if count > budget:
        parser.error(f"{count} triangles, over the budget of {budget}")

    others = [image.get("uri", image.get("name", "an embedded image")) for image in document.get("images", [])
              if image.get("mimeType", "image/png") != "image/png" or not image.get("uri", ".png").lower().endswith(".png")]
    if others:
        parser.error(f"textures must be PNG (the console's textures are imported as PNG): convert {', '.join(others)}")

    folder.mkdir()
    name = args.folder
    binary, pngs = unpack_images(document, binary, args.glb.parent, folder, name)
    write_glb(folder / f"{name}.glb", document, binary)
    (folder / f"{name}.glb.import").write_text(GLB_IMPORT)
    for png in pngs:
        (folder / f"{png.name}.import").write_text(PNG_IMPORT.format(normal=int(png.stem.endswith("normal"))))
    (folder / "LICENSE.txt").write_text(licence.rstrip() + "\n" + (f"\nChanges: {args.changes}\n" if args.changes else ""))
    res = f"res://carousel/consoles/{name}"
    (folder / "console.tres").write_text(
        '[gd_resource type="Resource" script_class="ConsoleManifest" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://carousel/consoles/console_manifest.gd" id="1"]\n\n'
        f'[resource]\nscript = ExtResource("1")\nplatform = "{args.platform}"\nversion = &"{args.version}"\n'
        f'is_default = {"false" if base else "true"}\nname = "{args.name}"\nmodel_name = "{args.model_name}"\n'
        f'scene = "{res}/{name}.tscn"\ntriangle_budget = {budget}\n')
    (folder / f"{name}_shape.tres").write_text(
        '[gd_resource type="Resource" script_class="SeatShape" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://carousel/consoles/seat_shape.gd" id="1"]\n\n'
        '[resource]\nscript = ExtResource("1")\nseat_centre = Vector3(0, 0, 0)\n')
    shown = "".join(line + "\n" for line in scene_values(base)) if base else ""
    (folder / f"{name}.tscn").write_text(
        '[gd_scene format=3]\n\n'
        '[ext_resource type="Script" path="res://carousel/consoles/glb_console.gd" id="1"]\n'
        f'[ext_resource type="Resource" path="{res}/{name}_shape.tres" id="2"]\n'
        f'[ext_resource type="PackedScene" path="{res}/{name}.glb" id="3"]\n\n'
        f'[node name="{"".join(word.title() for word in name.split("_"))}" type="Node3D"]\n'
        f'script = ExtResource("1")\nshape = ExtResource("2")\n{shown}\n'
        '[node name="Model" parent="." instance=ExtResource("3")]\n')
    if base:
        manifest = CONSOLES / base / "console.tres"
        text = manifest.read_text()
        listed = re.search(r'^variants = PackedStringArray\((.*)\)$', text, re.M)
        if listed:
            text = text.replace(listed.group(0), f'variants = PackedStringArray({listed.group(1)}, "{name}")')
        else:
            text = text.rstrip("\n") + f'\nvariants = PackedStringArray("{name}")\n'
        manifest.write_text(text)
    variant = add_variant_entry(name, args.platform)
    take_off_awaited(name)
    add_credit(credit.group(0))

    nodes = [node.get("name", "") for node in document.get("nodes", [])]
    logos = [slot for slot in LOGO_SLOTS if not (APP / "studio/logos" / slot / f"{name}.png").is_file()]
    gel = f'&"{base or name}":' in (APP / "studio/studio_tokens.gd").read_text()
    print(f"""{folder.relative_to(ROOT)} made: {count} triangles (budget {budget}), {len(pngs)} textures, nodes {nodes}.
ConsoleVariant {name.upper()}: {variant}; README credit added{f'; listed among the models of {base}' if base else ''}.

To measure and fill:
- {name}_shape.tres: seat_centre (mm, the model's axes) and seat_degrees, where the medium stands once in.
- {name}.tscn: way_in (the way the medium comes down) and pose (0 way in, 1 standing, 2 three quarters){' (from ' + base + ')' if base else ''};
  moving parts, once the launch is designed (docs/adding-a-console.md, "Moving parts").
- console.tres: ring_size, the console's size on the ordering ring (zero weighs it as the PS2).
- README.md: the console in the table of consoles.
- app/test/carousel/consoles/console_folders_test.gd: HOUSINGS (the parts the medium lies in), OPEN_EDGES and any
  FOLDED_EDGES, as the test reports them.
- Logos{' missing: ' + ', '.join(f'app/studio/logos/{slot}/{name}.png' for slot in logos) if logos else ': found'}.
- Colour (gel): {'found' if gel else 'none yet; the maintainers add it (the console shows the neutral one)'}.
Then: git add the new files, import (godot --headless --path app --import) and run
scripts/test_godot.sh res://test/carousel/consoles and (cd kotlin && ./gradlew :core:test).""")


if __name__ == "__main__":
    main()
