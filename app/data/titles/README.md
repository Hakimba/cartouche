Game titles and serials from [Redump](http://redump.org) (discs) and [No-Intro](https://no-intro.org)
(cartridges), as published in [libretro-database](https://github.com/libretro/libretro-database)
(`metadat/redump`, `metadat/no-intro`), used under the [Creative Commons Attribution-ShareAlike
4.0](https://creativecommons.org/licenses/by-sa/4.0/) license (see LICENSE.md). These files are
distributed under the same license.

- `ps2.tsv`: from `metadat/redump/Sony - PlayStation 2.dat` at libretro-database commit
  `dd2d75d15d5c50cca0c3ef601c32d4dbf6ba431c` (list version 2026.08.01).
- `gba.tsv`: from `metadat/no-intro/Nintendo - Game Boy Advance.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `wii.tsv`: from `metadat/redump/Nintendo - Wii.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `psx.tsv`: from `metadat/redump/Sony - PlayStation.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `gc.tsv`: from `metadat/redump/Nintendo - GameCube.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `xbox.tsv`: from `metadat/redump/Microsoft - Xbox.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `xbox360.tsv`: from `metadat/redump/Microsoft - Xbox 360.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `nes.tsv`: from `metadat/no-intro/Nintendo - Nintendo Entertainment System.dat` at libretro-database
  commit `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `snes.tsv`: from `metadat/no-intro/Nintendo - Super Nintendo Entertainment System.dat` at
  libretro-database commit `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `n64.tsv`: from `metadat/no-intro/Nintendo - Nintendo 64.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `gb.tsv`: from `metadat/no-intro/Nintendo - Game Boy.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).
- `gbc.tsv`: from `metadat/no-intro/Nintendo - Game Boy Color.dat` at libretro-database commit
  `9a899f5b13ed1c355491e342203be29bc573323b` (list version 2026.10.07).

Changes: only each game's name and serials are kept, one line per name (`name<TAB>serials`), and
serials repeated with a disc suffix (`SLPM-65002-0`) are reduced to the plain serial.
`scripts/dat_titles.py` regenerates a file from a DAT; a platform's list is named after its id.
