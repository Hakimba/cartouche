Which disc scans each game has in the [LaunchBox Games
Database](https://gamesdb.launchbox-app.com), read from its public dump (`Metadata.zip`, published
daily). Only names, alternate names, regions and image file names are kept; the images themselves
are downloaded on the device, from `https://images.launchbox-app.com/`, and never stored in the
repository. Fan-made images are left out.

- `ps2.tsv`: from the dump of the date on its first line (`Sony Playstation 2`).

`dev/launchbox_art.py` regenerates a file from the dump; a platform's file is named after its id.
