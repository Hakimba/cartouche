# Adding a medium

**You are here.** A medium is the physical object a game comes on, a disc or a cartridge, and one folder under
`app/carousel/media/`. The games row, the labels, the properties, the insertion and every console's seat read it
([architecture/godot.md](architecture/godot.md)). It depends on the model code in `app/carousel/models/`. A
platform names its media in its profile, so a medium is added together with its platform's data
([architecture/core.md](architecture/core.md#adding-a-platform)) or its console
([adding-a-console.md](adding-a-console.md)).

The folder is named as `app/data/platforms/profiles.json` names the medium in a platform's `medium` (`ps2_dvd`,
`snes_pal_cart`). Nothing in the app reads that name for meaning: whether a medium is a disc or a cartridge is its
manifest's kind.

## In short

Most media are made with one command, from a ruler and a photo of the real one:

```sh
# a disc: where its label and mirror start, its recorded area, and a band left unrecorded if it has one
python3 scripts/new_medium.py dreamcast_gd disc --hub 19 --data 23,58 --gap 26.5,35

# a cartridge shaped as a rounded box: width, height, depth; the label from the front's top left corner
python3 scripts/new_medium.py switch_card box --size 21,31,3.3 --label 1.5,5,18,24.5 --corner 1.5 --grip 1,2,1
```

All lengths are in millimetres. `scripts/new_medium.py --help` lists every option (`--colour` for a cartridge's
plastic, `--pose-like` for the medium whose pose on the games screen it starts from). The script writes:

- the folder with its manifest, its dimensions and its scene;
- its pose in `app/data/media_poses.json`, copied from a medium of its kind;
- for a cartridge, its front in the `art` of each platform declaring it in `app/data/platforms/profiles.json`: the
  front's proportion and where the label sits on it, computed from the label box, so that a scan of the cartridge is
  cut to its label;
- the medium taken off `AWAITING` in `app/test/carousel/media/media_folders_test.gd`.

Then run the tests below and look at it: `scripts/render_console.sh <medium>` draws it from six points of view into
`build/renders/<medium>.png`, to set beside photos of the real one. Adjust a value in its `<medium>_shape.tres`, or
its pose in `media_poses.json`, and look again.

## The contract

A medium is a scene whose root holds its parts: `ShapedMesh`es of one `ModelShape`. One part is the `Label`, drawn
with `app/carousel/models/label.gdshader`, its face's UV square the label image. The shape's `title_area()` and
`platform_area()` say where a game without a scan has its title and platform drawn, and
`progress_ring_radius()` where its download ring turns.

A medium stands in its own frame, the one a console's seat takes. Its root's scale is its size in the games row
only: on its way into a console it takes its real size.

## The files of a folder

| File | Holds |
|---|---|
| `medium.tres` | the manifest (`MediumManifest`): its kind in `media` (`dvd`, `minidisc` or `cartridge`, as its platforms declare), its scene, its triangle budget |
| `<medium>_shape.tres` | the measured dimensions |
| `<medium>.tscn` | the scene, on the existing shaders |
| `<medium>_shape.gd`, `<medium>_geometry.gd` | a shape and geometry of its own, only when the shared ones cannot express it |

## The shared shapes

- **Discs**, `DiscShape` and `DiscGeometry`: radius, hole, the stacking ring, the label and the mirror from the hub to
  the rim, the recorded area, and `data_gap`, a band left unrecorded across it (the ring between a GD-ROM's two
  areas).
- **Box cartridges**, `BoxCartShape` and `BoxCartGeometry`: a rounded box, its front's and back's edges rounded, the
  label in a recess of the front (`label`, as a scan shows it from the top left corner), and `grip`, ridges across
  the front above the label. The Mega Drive's, the Master System's and the Switch's game card are made so.

A cartridge whose outline, back or connector shows more than a box (the NES's notches and stub, the Game Boy's
ridged back, the GBA's hump) has a shape of its own in its folder, built from `ShapeGeometry`'s pieces: copy the
closest one (`nes_cart`, `gb_cart`, `gba_cart`). A family shared by several media lives in its first medium's
folder and the others build on it (`GbCartShape` in `app/carousel/media/gb_cart/`). A medium that looks exactly
like another names the other's scene in its manifest, as `app/carousel/media/gbc_cart/medium.tres` does.

There is no solid subtraction. A label's recess or a screw hole is faces laid around a hole and sunk into it
(`ShapeGeometry`'s `holed` and `sunk`). A slit too narrow to show its walls from the carousel's distance is a dark
face just over the surface.

A medium drawn from a downloaded model (a glb) is not accepted yet: the app would show it, its title drawn where
the defaults put it, but the tests want every part a `ShapedMesh` built closed. The first such medium brings a
label face of its own kind of shape and the tests' check for it.

## Shared files a new medium needs

- `app/data/media_poses.json`: its pose on the games screen (the script writes one). Without an entry it takes the
  disc's.
- `app/data/carousel/appearance.json`: its kind's insertion and label colours, only when its kind is new.
- The lights of the games screen are designed per medium in the developer tool (`app/data/studio_lights.json`, never
  edited by hand); a medium without its own takes the default lights.
- The art data of its platform, for cartridges (`app/data/prints/`): see
  [architecture/core.md](architecture/core.md#platforms-and-launches).

Without a folder, a medium shows as the one its kind falls back to (`kind_media` in
`app/data/carousel/appearance.json`). A folder with problems is traced and left out.

## The tests that hold it

```sh
GODOT=$GODOT scripts/test_godot.sh res://test/carousel/media res://test/carousel/shipped_shapes_test.gd \
  res://test/carousel/consoles res://test/studio/games
```

`app/test/carousel/media/media_folders_test.gd` runs on every folder. It checks the manifest loads and its medium
is declared by platforms of its kind (INV-14), that every medium a platform declares has its folder (or is listed
in `AWAITING`), that each label face has the proportions of the labels cut for it and sits where the crop cuts
them, and that a folder with problems is left out. `shipped_shapes_test.gd` builds every medium from its dimensions:
accepted by its shape's rules, closed, its faces turned outwards. `console_folders_test.gd` checks every medium
comes down its console's way in at its real size, clear of the console's parts
([adding-a-console.md](adding-a-console.md#the-tests-that-hold-it)). `games_layout_test.gd` checks a medium stands
in the row as the others of its kind. The disc family has its own tests in
`app/test/carousel/model_geometry_test.gd`.

`scripts/render_console.sh <medium>` and `scripts/export_console.sh <medium>` take a medium's folder as they take a
console's ([adding-a-console.md](adding-a-console.md#tools)).

## Neighbours

- [adding-a-console.md](adding-a-console.md): the console a medium goes into.
- [architecture/godot.md](architecture/godot.md#models-and-shaders): the model code.
- [architecture/core.md](architecture/core.md#platforms-and-launches): profiles and `MediaRule`.
- [testing.md](testing.md#gdscript). Back to the entry: [README.md](README.md).
