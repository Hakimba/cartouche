Disc titles and serials from [Redump](http://redump.org), as published in
[libretro-database](https://github.com/libretro/libretro-database) (`metadat/redump`), used under
the [Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
license (see LICENSE.md). These files are distributed under the same license.

- `ps2.tsv`: from `Sony - PlayStation 2.dat` at libretro-database commit
  `dd2d75d15d5c50cca0c3ef601c32d4dbf6ba431c` (list version 2026.08.01).

Changes: only each disc's name and serials are kept, one line per name (`name<TAB>serials`), and
serials repeated with a disc suffix (`SLPM-65002-0`) are reduced to the plain serial.
`dev/redump_titles.py` regenerates a file from a DAT; a platform's list is named after its id.
