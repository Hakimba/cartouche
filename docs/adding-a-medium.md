# Adding a medium

A medium is the physical object a game comes on, a disc or a cartridge: one folder under `app/carousel/media/`,
named as a platform's `medium` names it in `app/data/platforms/profiles.json` (`ps2_dvd`, `snes_pal_cart`). The
games row, the labels, the properties, the insertion and every console's seat read it. Whether it is a disc or a
cartridge is its manifest's kind, never its name.

## Steps

1. **Measure the real one** with a ruler and a photo. All lengths are millimetres.
2. **Run the scaffold** (`scripts/new_medium.py --help` lists every option):

   ```sh
   # a disc: where its label and mirror start, its recorded area, and a band left unrecorded if it has one
   python3 scripts/new_medium.py dreamcast_gd disc --hub 19 --data 23,58 --gap 26.5,35

   # a cartridge shaped as a rounded box: width, height, depth; the label from the front's top left corner
   python3 scripts/new_medium.py switch_card box --size 21,31,3.3 --label 1.5,5,18,24.5 --corner 1.5 --grip 1,2,1
   ```

   It writes the folder (manifest, dimensions, scene), the medium's pose in `app/data/media_poses.json` (copied
   from a medium of its kind, or `--pose-like`), for a cartridge its front in the `art` of each platform declaring
   it (the front's proportion and the label's crop, so a scan is cut to its label), and takes the medium off
   `AWAITING` in `app/test/assets/media_assets_test.gd`.
3. **Look at it.** `scripts/render_console.sh <medium>` draws it from six points of view into
   `build/renders/<medium>.png`, to set beside photos. Adjust a value in `<medium>_shape.tres` or its pose, and
   look again.
4. **Check.**

   ```sh
   GODOT=$GODOT scripts/test_godot.sh res://test/carousel/media res://test/carousel/shipped_shapes_test.gd \
     res://test/carousel/consoles res://test/assets res://test/studio/games
   ```

## The files of a folder

| File | Holds |
|---|---|
| `medium.tres` | the manifest (`MediumManifest`): its kind in `media` (`dvd`, `minidisc` or `cartridge`, as its platforms declare), its scene, its triangle budget, and for a baked medium where its title and platform are drawn (`title_area`, `platform_area`) |
| `<medium>_shape.tres` | the measured dimensions, for a disc or a box cartridge |
| `<medium>.tscn` | the scene, on the shared shaders. One part is the `Label`, drawn with `app/carousel/models/label.gdshader`, its face's UV square the label image |
| `<medium>_<part>.res` | a baked part's mesh, for a cartridge the shared shapes cannot express |

A shape's `title_area()`, `platform_area()` and `progress_ring_radius()` say where a game without a scan has its
title, its platform and its download ring drawn. A medium stands in its own frame, the one a console's seat takes. Its root's scale is its size in the games row
only: on its way into a console it takes its real size.

## Which shape

| The medium | Is made from |
|---|---|
| A disc | `DiscShape` and `DiscGeometry`: radius, hole, stacking ring, label and mirror from the hub to the rim, recorded area, and `data_gap`, a band left unrecorded (a GD-ROM's ring) |
| A cartridge that is a rounded box (Mega Drive, Master System, a Switch card) | `BoxCartShape` and `BoxCartGeometry`: the label in a recess of the front, and `grip`, ridges above it |
| A cartridge whose outline, back or connector shows more than a box (`nes_cart`, `gb_cart`, `gba_cart`) | baked meshes, one `<medium>_<part>.res` per part (an `ArrayMesh` with its label's UVs), modelled outside the app |
| A medium that looks exactly like another | the other's scene, named in its manifest, as `app/carousel/media/gbc_cart/medium.tres` does |

- There is no solid subtraction: a recess or a hole is faces laid around a hole and sunk into it (`holed` and
  `sunk` of `ShapeGeometry`). A slit too narrow to show its walls is a dark face just over the surface.
- A medium drawn from a glb is not accepted yet: the tests want every part a closed mesh of the scene's root.

## Shared files

| File | What a medium needs there | Without it |
|---|---|---|
| `app/data/media_poses.json` | its pose on the games screen (the scaffold writes one) | the disc's pose |
| `app/data/carousel/appearance.json` | its kind's insertion and label colours, only when the kind is new | |
| `app/data/studio_lights.json` | its lights on the games screen, written by the maintainers' tuning tool | the default lights |
| `app/data/prints/` and the platform's art data | for cartridges ([adding-a-platform.md](adding-a-platform.md)) | no label |

Without a folder, a medium shows as the one its kind falls back to (`kind_media` in
`app/data/carousel/appearance.json`). A folder with problems is traced and left out.

## What the tests hold

| Test | Holds |
|---|---|
| `app/test/carousel/media/media_folders_test.gd` | every folder: the manifest loads, its medium is declared by platforms of its kind (INV-14), it stays under its triangle budget; a folder with problems is left out |
| `app/test/assets/media_assets_test.gd` | every medium a platform declares has its folder or is in `AWAITING`; each label face has the proportions of the labels cut for it; every model draws a label; every medium is accepted by its shape's rules and closed |
| `app/test/assets/console_assets_test.gd` | every medium comes down its console's way in at its real size, clear of the console's parts |
| `games_layout_test.gd`, `app/test/carousel/model_geometry_test.gd` | a medium stands in the row as the others of its kind; the disc family's geometry |
