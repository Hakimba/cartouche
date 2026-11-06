#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Makes a medium's folder from its measurements, as docs/adding-a-medium.md describes: its manifest, its
dimensions and its scene in app/carousel/media/<id>/, its pose on the games screen, and the medium taken off the
list of media still awaited by the tests.

  scripts/new_medium.py dreamcast_gd disc --hub 19 --data 23,58 --gap 26.5,35
  scripts/new_medium.py switch_card box --size 21,31,3.3 --label 1.5,5,18,24 --grip 1,1,1

A disc is a DiscShape (app/carousel/models/disc_shape.gd), a box cartridge a BoxCartShape
(app/carousel/models/box_cart_shape.gd); every length is in millimetres. A box cartridge's label crop is written
into the fronts of the platforms declaring it (app/data/platforms/profiles.json), computed from its label box."""
import argparse
import json
import re
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent.parent / "app"
MEDIA = APP / "carousel/media"
POSES = APP / "data/media_poses.json"
APPEARANCE = APP / "data/carousel/appearance.json"
PROFILES = APP / "data/platforms/profiles.json"
FOLDERS_TEST = APP / "test/carousel/media/media_folders_test.gd"
DISC_TEMPLATE = MEDIA / "ps2_dvd/ps2_dvd.tscn"


def numbers(count):
    def parse(text):
        values = [float(v) for v in text.split(",")]
        if len(values) != count:
            raise argparse.ArgumentTypeError(f"{count} numbers separated by commas expected: {text}")
        return values
    return parse


def colour(text):
    if not re.fullmatch(r"#?[0-9a-fA-F]{6}", text):
        raise argparse.ArgumentTypeError(f"a colour as #rrggbb expected: {text}")
    rgb = [int(text.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "Color(%s, 1)" % ", ".join(f"{c:.3g}" for c in rgb)


def godot(value):
    if isinstance(value, list):
        return "Vector%d(%s)" % (len(value), ", ".join(repr(float(v)) for v in value))
    return value if isinstance(value, (str, int)) else repr(float(value))


def resource(script_class, script, values):
    lines = [f'[gd_resource type="Resource" script_class="{script_class}" format=3]', "",
             f'[ext_resource type="Script" path="{script}" id="1"]', "", "[resource]", 'script = ExtResource("1")']
    lines += [f"{key} = {godot(value)}" for key, value in values.items()]
    return "\n".join(lines) + "\n"


def pascal(medium):
    return "".join(word.capitalize() for word in medium.split("_"))


def disc(medium, args):
    hub = args.hub
    shape = {"radius": args.radius, "hole": args.hole, "ring": hub - 2.0, "label_inner": hub, "mirror_inner": hub,
             "label_outer": args.radius - 1.0, "mirror_outer": args.radius - 1.5,
             "data_inner": args.data[0], "data_outer": args.data[1]}
    if args.gap:
        shape["data_gap"] = args.gap
    scene = DISC_TEMPLATE.read_text()
    scene = re.sub(r' uid="uid://[a-z0-9]+"', "", scene.split("\n", 1)[0]) + "\n" + scene.split("\n", 1)[1]
    scene = scene.replace("ps2_dvd", medium).replace('[node name="Ps2Dvd"', f'[node name="{pascal(medium)}"')
    return resource("DiscShape", "res://carousel/models/disc_shape.gd", shape), scene, 9000


BOX_SCENE = """[gd_scene format=3]

[ext_resource type="Script" path="res://carousel/models/shaped_mesh.gd" id="1"]
[ext_resource type="Resource" path="res://carousel/media/{medium}/{medium}_shape.tres" id="2"]
[ext_resource type="Shader" path="res://carousel/models/label.gdshader" id="3"]
[ext_resource type="Shader" path="res://carousel/models/solid.gdshader" id="4"]

[sub_resource type="PrimitiveMesh" id="label_mesh"]
script = ExtResource("1")
shape = ExtResource("2")
part = &"label"
detail = 64

[sub_resource type="ShaderMaterial" id="label_material"]
shader = ExtResource("3")
shader_parameter/roughness = 0.5
shader_parameter/varnish = 0.3

[sub_resource type="PrimitiveMesh" id="shell_mesh"]
script = ExtResource("1")
shape = ExtResource("2")
part = &"shell"
detail = 64

[sub_resource type="ShaderMaterial" id="shell_material"]
shader = ExtResource("4")
shader_parameter/albedo = {colour}
shader_parameter/roughness = 0.6

[node name="{node}" type="Node3D"]

[node name="Label" type="MeshInstance3D" parent="."]
mesh = SubResource("label_mesh")
surface_material_override/0 = SubResource("label_material")

[node name="Shell" type="MeshInstance3D" parent="."]
mesh = SubResource("shell_mesh")
surface_material_override/0 = SubResource("shell_material")
"""


def box(medium, args):
    width, height, depth = args.size
    shape = {"width": width, "height": height, "depth": depth, "corner": args.corner,
             "label": "Rect2(%s)" % ", ".join(repr(v) for v in args.label)}
    if args.grip:
        shape["grip"] = args.grip
    scene = BOX_SCENE.format(medium=medium, node=pascal(medium), colour=args.colour)
    return resource("BoxCartShape", "res://carousel/models/box_cart_shape.gd", shape), scene, 1500


def front(args):
    """The front a scan of this cartridge shows, as profiles.json has it: its width over its height, its label's
    edges as fractions of the front from its top left."""
    width, height, _depth = args.size
    left, top, label_width, label_height = args.label
    return {"proportion": round(width / height, 3), "label": {
        "left": round(left / width, 3), "top": round(top / height, 3),
        "width": round(label_width / width, 3), "height": round(label_height / height, 3)}}


def with_fronts(medium, found):
    """The hand-formatted profiles with the medium's front added to each platform declaring it, on its one line, and
    those platforms; nothing is written, so a profile it cannot edit stops the script before the folder is made."""
    text = PROFILES.read_text()
    profiles = json.loads(text)
    declaring = [p for p, profile in profiles.items() if medium in profile["medium"].values()]
    for platform in declaring:
        fronts = profiles[platform].get("art", {}).get("fronts")
        if fronts is not None and medium in fronts:
            continue
        line = re.compile(r'^(  "%s": \{.*?)\}(,?)$' % re.escape(platform), re.M)
        if fronts is not None or not line.search(text):
            sys.exit(f"{platform}: add the front of {medium} to its art in {PROFILES} by hand: {json.dumps(found)}")
        art = json.dumps({"kind": "cartridge_front", "fronts": {medium: found}})
        text = line.sub(lambda m: f'{m.group(1)}, "art": {art}}}{m.group(2)}', text, count=1)
    return text, declaring


def pose(medium, like):
    poses = json.loads(POSES.read_text())
    poses["media"][medium] = poses["media"][like]
    POSES.write_text(json.dumps(poses, indent=2, sort_keys=True) + "\n")


def unawait(medium):
    text = FOLDERS_TEST.read_text()
    awaiting = re.search(r"^const AWAITING: Array\[String\] = \[(.*)\]$", text, re.M)
    names = [n for n in re.findall(r'"([^"]+)"', awaiting.group(1)) if n != medium]
    listed = ", ".join(f'"{n}"' for n in names)
    FOLDERS_TEST.write_text(text[:awaiting.start(1)] + listed + text[awaiting.end(1):])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("medium", help="the medium's id, as profiles.json names it (dreamcast_gd)")
    kinds = parser.add_subparsers(dest="family", required=True)
    one = kinds.add_parser("disc", help="an optical disc")
    one.add_argument("--kind", default="dvd", choices=["dvd", "minidisc"])
    one.add_argument("--radius", type=float, default=60.0)
    one.add_argument("--hole", type=float, default=7.5, help="the centre hole's radius")
    one.add_argument("--hub", type=float, required=True, help="where the label and the mirror start, from the centre")
    one.add_argument("--data", type=numbers(2), required=True, help="the recorded area's inner and outer radii")
    one.add_argument("--gap", type=numbers(2), help="a band left unrecorded across the data, its radii")
    other = kinds.add_parser("box", help="a cartridge shaped as a rounded box")
    other.add_argument("--size", type=numbers(3), required=True, help="width, height, depth")
    other.add_argument("--label", type=numbers(4), required=True,
                       help="the label's left, top (from the front's top left corner), width, height")
    other.add_argument("--corner", type=float, default=2.0, help="the outline's corner radius")
    other.add_argument("--colour", type=colour, default="#1a1a1a", help="the shell's colour, #rrggbb")
    other.add_argument("--grip", type=numbers(3), help="ridges across the front's top: count, pitch, height")
    for kind in (one, other):
        kind.add_argument("--pose-like", help="the medium whose pose on the games screen it takes (its kind's)")
    args = parser.parse_args()

    medium = args.medium
    folder = MEDIA / medium
    if not re.fullmatch(r"[a-z0-9]+(_[a-z0-9]+)+", medium):
        sys.exit(f"{medium}: a medium is named <platform>_<medium>, in lower case")
    if folder.exists():
        sys.exit(f"{folder} exists already")
    shape, scene, budget = (disc if args.family == "disc" else box)(medium, args)
    kind = args.kind if args.family == "disc" else "cartridge"
    profiles, declaring = with_fronts(medium, front(args)) if args.family == "box" else (None, [])
    folder.mkdir()
    (folder / f"{medium}_shape.tres").write_text(shape)
    (folder / f"{medium}.tscn").write_text(scene)
    (folder / "medium.tres").write_text(resource("MediumManifest", "res://carousel/media/medium_manifest.gd", {
        "media": f'"{kind}"', "scene": f'"res://carousel/media/{medium}/{medium}.tscn"', "triangle_budget": budget}))
    pose(medium, args.pose_like or json.loads(APPEARANCE.read_text())["kind_media"][kind])
    unawait(medium)
    print(f"made {folder.relative_to(APP.parent)}")
    if profiles:
        PROFILES.write_text(profiles)
        print(f"its front in the art of {', '.join(declaring)}")


if __name__ == "__main__":
    main()
