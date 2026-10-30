# Sounds

**You are here.** Every sound the app plays is made in code from pure tones, and one table says which gesture of
which screen plays which sound. This page covers that table, the tool that turns it into sound files, and how the
app plays them. The tool depends on Python and ffmpeg. The app side depends on nothing but Godot, and every screen
([architecture/godot.md](architecture/godot.md)) calls it.

## The table

`scripts/audio/sounds.json` is the one source:

| Key | Holds |
|---|---|
| `screens` | every screen, with its gestures and the cue each gesture plays |
| `cues` | each cue's sound, or none for a silent cue |
| `sounds` | the recipes: each sound a few pure tones, filtered and shaped |
| `roles` | the limits a sound of each role must meet (length, loudness, attack, brightness) |
| `validated` | the sounds the maintainers approved by ear, each locked by its recipe's hash |
| `candidates` | sounds to try against the current ones |

## The tool

`scripts/audio/sfx.py` needs ffmpeg, sox, and Python's numpy, scipy and Pillow.

```sh
python3 scripts/audio/sfx.py render      # the sounds into app/audio/sfx, the cue table into app/audio/cues.json
python3 scripts/audio/sfx.py qa          # measures every sound against its role, exits 1 on any miss
python3 scripts/audio/sfx.py map         # writes build/sound-map/index.html: every screen, its gestures, their sounds
python3 scripts/audio/test_sfx.py        # proves each qa check catches the defect it is for
```

A threshold is never relaxed to let a sound pass: change the recipe.

## In the app

`SoundEffects` (`app/audio/sound_effects.gd`) is the `Sounds` autoload. It holds one player per cue
(`SoundEffects.Cue`) on the `UI` bus, each playing the file `app/audio/cues.json` names for it.

- A gesture plays its sound with one call where it happens: `Sounds.play(SoundEffects.Cue.SELECT)`. One press plays
  one sound at most.
- A held direction repeats its cue. The cues in `REPEATED` play at most once per short gap, each a little higher or
  lower, so a fast scroll does not rattle.
- A screen in the `SoundEffects.MOVES` group has its focus moves played for it: a focus moved by a direction plays
  `MOVE`, or the cue its nearest parent names in its `MOVE_SOUND` meta.
- `Sounds.level` is the sound level setting, from silent to full. `ScreenFlow` sets it from the settings.

## Adding a sound to a gesture

1. In `scripts/audio/sounds.json`, add the gesture to its screen in `screens`, and its cue to `cues` with a sound, new
   or existing.
2. For a new cue, add its name to the `Cue` enum of `app/audio/sound_effects.gd`. The enum name in lower case is
   its key in `cues`.
3. Run `python3 scripts/audio/sfx.py render`, then `qa`.
4. Call `Sounds.play` where the gesture happens.
5. `app/test/audio/gestures_test.gd` checks what the screens' gestures play. Add the gesture there.

## Neighbours

- [architecture/godot.md](architecture/godot.md): the screens that play the cues.
- [debug-bridge.md](debug-bridge.md): `sound` and `sounds` play sounds on a running build without a rebuild.
- [testing.md](testing.md#gdscript). Back to the entry: [README.md](README.md).
