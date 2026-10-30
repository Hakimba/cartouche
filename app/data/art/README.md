Which scans of its disc or cartridge each game has in the [LaunchBox Games
Database](https://gamesdb.launchbox-app.com), read from its public dump (`Metadata.zip`, published
daily). Only names, alternate names, regions and image file names are kept; the images themselves
are downloaded on the device, from `https://images.launchbox-app.com/`, and never stored in the
repository. Fan-made images are left out.

- `ps2.tsv`: from the dump of the date on its first line (`Sony Playstation 2`, disc scans).
- `gba.tsv`: from the dump of the date on its first line (`Nintendo Game Boy Advance`, `Cart - Front`).
- `wii.tsv`: from the dump of the date on its first line (`Nintendo Wii`, disc scans).
- `psx.tsv`: from the dump of the date on its first line (`Sony Playstation`, disc scans).
- `gc.tsv`: from the dump of the date on its first line (`Nintendo GameCube`, disc scans).
- `xbox.tsv`: from the dump of the date on its first line (`Microsoft Xbox`, disc scans).
- `xbox360.tsv`: from the dump of the date on its first line (`Microsoft Xbox 360`, disc scans).
- `nes.tsv`: from the dump of the date on its first line (`Nintendo Entertainment System`, `Cart - Front`).
- `snes.tsv`: from the dump of the date on its first line (`Super Nintendo Entertainment System`, `Cart - Front`).
- `n64.tsv`: from the dump of the date on its first line (`Nintendo 64`, `Cart - Front`).
- `gb.tsv`: from the dump of the date on its first line (`Nintendo Game Boy`, `Cart - Front`).
- `gbc.tsv`: from the dump of the date on its first line (`Nintendo Game Boy Color`, `Cart - Front`).

`scripts/launchbox_art.py` regenerates a file from the dump; a platform's file is named after its id.
