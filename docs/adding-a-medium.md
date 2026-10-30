# Adding a medium

**You are here.** A medium is the physical object a game comes on, a disc or a cartridge, and one folder under
`app/carousel/media/`. The games row, the labels, the properties, the insertion and every console's seat read it
([architecture/godot.md](architecture/godot.md)). It depends on the model code in `app/carousel/models/`. A
platform names its media in its profile, so a medium is added together with its platform's data
([architecture/core.md](architecture/core.md#adding-a-platform)) or its console
([adding-a-console.md](adding-a-console.md)).

The folder is named as `app/data/platforms/profiles.json` names the medium in a platform's `medium` (`ps2_dvd`,
`snes_pal_cart`). Copy `app/carousel/media/ps2_dvd/` for a disc, `app/carousel/media/nes_cart/` for a cartridge.

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

Discs are one family, `DiscShape` and `DiscGeometry` in `app/carousel/models/`: a disc folder needs only its
manifest, dimensions and scene. Cartridges build on `ShapeGeometry`'s pieces. A cartridge family shared by several
media lives in its first medium's folder and the others build on it (`GbCartShape` in
`app/carousel/media/gb_cart/`). A medium that looks exactly like another names the other's scene in its manifest,
as `app/carousel/media/gbc_cart/medium.tres` does.

There is no solid subtraction. A label's recess or a screw hole is faces laid around a hole and sunk into it
(`ShapeGeometry`'s `holed` and `sunk`). A slit too narrow to show its walls from the carousel's distance is a dark
face just over the surface.

Without a folder, a medium shows as the one its kind falls back to (`kind_media` in
`app/data/carousel/appearance.json`). A folder with problems is traced and left out.

## Shared files a new medium needs

- `app/data/media_poses.json`: its pose on the games screen. Without an entry it takes the default.
- `app/data/carousel/appearance.json`: its kind's insertion and label colours, when its kind is new.
- The cartridge platforms' `art` in `app/data/platforms/profiles.json`: the front's proportion and label crop for
  each shape of cartridge their scans show ([architecture/core.md](architecture/core.md#platforms-and-launches)).

## The tests that hold it

`app/test/carousel/media/media_folders_test.gd` runs on every folder. It checks the manifest loads and its medium
is declared by platforms of its kind (INV-14), that every medium a platform declares has its folder (or is listed
in `AWAITING`), that each label face has the proportions of the labels cut for it, and that a folder with problems
is left out. `console_folders_test.gd` checks every medium comes down its console's way in at its real size, clear
of the console's parts ([adding-a-console.md](adding-a-console.md#the-tests-that-hold-it)). The disc family has its
own tests in `app/test/carousel/model_geometry_test.gd`.

`dev/render_console.sh <medium>` and `dev/export_console.sh <medium>` take a medium's folder as they take a
console's ([adding-a-console.md](adding-a-console.md#tools)).

## Neighbours

- [adding-a-console.md](adding-a-console.md): the console a medium goes into.
- [architecture/godot.md](architecture/godot.md#models-and-shaders): the model code.
- [architecture/core.md](architecture/core.md#platforms-and-launches): profiles and `MediaRule`.
- [testing.md](testing.md#gdscript). Back to the entry: [ONBOARDING.md](ONBOARDING.md).
