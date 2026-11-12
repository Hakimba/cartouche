# Sounds

Every sound is made in code from pure tones. One table, `scripts/audio/sounds.json`, says which gesture of which
screen plays which sound:

| Key | Holds |
|---|---|
| `screens` | every screen, its gestures, and the cue each gesture plays |
| `cues` | each cue's sound, or none for a silent cue |
| `sounds` | the recipes: each sound a few pure tones, filtered and shaped |
| `roles` | the limits a sound of each role must meet (length, loudness, attack, brightness) |
| `validated` | the sounds the maintainers approved by ear, each locked by its recipe's hash |
| `candidates` | sounds to try against the current ones |

`scripts/audio/sfx.py` needs ffmpeg, sox, and Python's numpy, scipy and Pillow:

```sh
python3 scripts/audio/sfx.py render      # the sounds into app/audio/sfx, the cue table into app/audio/cues.json
python3 scripts/audio/sfx.py qa          # measures every sound against its role, exits 1 on any miss
python3 scripts/audio/sfx.py map         # writes build/sound-map/index.html: every screen, its gestures, their sounds
python3 scripts/audio/test_sfx.py        # proves each qa check catches the defect it is for
```

A threshold is never relaxed to let a sound pass: change the recipe.

## In the app

`SoundEffects` (`app/audio/sound_effects.gd`) is the `Sounds` autoload: one player per cue (`SoundEffects.Cue`),
each playing the file `app/audio/cues.json` names.

- A gesture plays its sound with one call where it happens: `Sounds.play(SoundEffects.Cue.SELECT)`. One press
  plays one sound at most.
- The cues in `REPEATED` play at most once per short gap under a held direction, so a fast scroll does not rattle.
- A screen in the `SoundEffects.MOVES` group has its focus moves played for it: `MOVE`, or the cue its nearest
  parent names in its `MOVE_SOUND` meta.
- `Sounds.level` is the sound level setting; `ScreenFlow` sets it.

## Adding a sound to a gesture

1. In `scripts/audio/sounds.json`, add the gesture to its screen in `screens`, and its cue to `cues` with a sound,
   new or existing.
2. For a new cue, add its name to the `Cue` enum of `app/audio/sound_effects.gd`; the name in lower case is its key
   in `cues`.
3. Run `python3 scripts/audio/sfx.py render`, then `qa`.
4. Call `Sounds.play` where the gesture happens.
5. Add the gesture to `app/test/audio/gestures_test.gd`.

The debug bridge's `sound` and `sounds` commands play sounds on a running build without a rebuild
([debug-bridge.md](debug-bridge.md)).
