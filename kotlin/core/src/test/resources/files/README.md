Disc images the file readers' tests decode, made by `scripts/file_fixtures.py` (genisoimage, chdman).

- `disc.iso`: a 29-sector ISO 9660 volume whose SYSTEM.CNF boots `SLES_524.95`.
- `disc.bin`: the same volume as raw 2352-byte mode 1 sectors.
- `disc-crowded.iso`: the volume with 60 empty files more at its root, named to come before
  SYSTEM.CNF, whose record lies in the second sector of the root directory.
- The CHDs hold the volume padded with zeros to 64 sectors: `cd-cdlz.chd`, `cd-cdzl.chd` and
  `cd-cdfl.chd` (a codec the reader does not decode) as a cooked MODE1 track; `cd-mode1-raw.chd`,
  `cd-mode2-raw.chd`, `cd-mode2.chd` and `cd-mode2-form-mix.chd` as tracks of each type;
  `dvd-lzma.chd` and `dvd-zlib.chd` as 2048-byte sectors, as `createdvd` stores them.
- `dvd-runs.chd`: one 2048-byte sector per hunk, in `lzma`, with the `DVD ` metadata entry
  `createdvd` writes. It holds the volume padded with zeros to 32 sectors, then 40 sectors each
  filled with its number from 1 (a run of hunks of one codec, run-length coded in the map), then 4
  sectors of hashes (`sha256("<sector>.<i>")` for i from 0 to 63), which no codec shrinks: hunks
  stored as they are.
