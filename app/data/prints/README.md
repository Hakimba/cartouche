Cartridge ROM checksums (CRC32) from [No-Intro](https://no-intro.org), as published in
[libretro-database](https://github.com/libretro/libretro-database) (`metadat/no-intro`), used under
the [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
license (see LICENSE.md). These files are distributed under the same license.

All six files come from libretro-database commit `9a899f5b13ed1c355491e342203be29bc573323b` (list
version 2026.10.07), the same DATs as the cartridge lists in `../titles`:

- `nes.tsv`: `metadat/no-intro/Nintendo - Nintendo Entertainment System.dat`.
- `snes.tsv`: `metadat/no-intro/Nintendo - Super Nintendo Entertainment System.dat`.
- `n64.tsv`: `metadat/no-intro/Nintendo - Nintendo 64.dat`.
- `gb.tsv`: `metadat/no-intro/Nintendo - Game Boy.dat`.
- `gbc.tsv`: `metadat/no-intro/Nintendo - Game Boy Color.dat`.
- `gba.tsv`: `metadat/no-intro/Nintendo - Game Boy Advance.dat`.

Changes: only each ROM's game name and CRC32 are kept, one line per ROM (`name<TAB>CRC32`), sorted
by name. The DATs list a ROM in each form it is shared in, and each is kept under the game's name:
the plain ROM (an NES ROM without its iNES header, `.unh`; an N64 ROM in big-endian order, `.z64`),
whose CRC32 the app counts from a ROM file, and the headered NES ROM (`.nes`) and byte-swapped N64
ROM (`.v64`), whose CRC32 a zip archive records for its entry.
`dev/dat_titles.py --prints` regenerates a file from a DAT; a platform's file is named after its id.
