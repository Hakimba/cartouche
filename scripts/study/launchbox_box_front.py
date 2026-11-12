#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Per-game coverage of LaunchBox's `Box - Front` images, for the consoles Cartouche knows.

One line per platform: how many games the dump holds, how many of them have at least one box front,
and how many have one printed for North America or the World (what the app's region preference
would actually find). Images are counted per game, not per image: a game carries one box front per
region it was released in, so a per-image count runs past 100 %.

    scripts/study/launchbox_box_front.py Metadata.zip > boxart.tsv

The dump comes from https://gamesdb.launchbox-app.com/Metadata.zip (about 105 MB, published daily,
520 MB of XML inside). It is read as a stream, so memory stays in the hundreds of megabytes.
Platforms are named as LaunchBox names them; the second column is the id the app uses.
"""
import collections
import sys
import xml.sax
import zipfile

PLATFORMS = {
    "Nintendo Entertainment System": "nes",
    "Super Nintendo Entertainment System": "snes",
    "Nintendo 64": "n64",
    "Nintendo GameCube": "gc",
    "Nintendo Wii": "wii",
    "Nintendo Switch": "switch",
    "Nintendo Game Boy": "gb",
    "Nintendo Game Boy Color": "gbc",
    "Nintendo Game Boy Advance": "gba",
    "Nintendo DS": "nds",
    "Nintendo 3DS": "3ds",
    "Sony Playstation": "psx",
    "Sony Playstation 2": "ps2",
    "Sony PSP": "psp",
    "Sony Playstation Vita": "psvita",
    "Sega Genesis": "genesis",
    "Sega Master System": "master",
    "Sega Game Gear": "gamegear",
    "Sega Dreamcast": "dreamcast",
    "Sega Saturn": "saturn",
    "Sega CD": "segacd",
    "Atari 2600": "atari2600",
    "NEC TurboGrafx-16": "tg16",
    "Microsoft Xbox": "xbox",
    "Microsoft Xbox 360": "xbox360",
}
BOX_FRONT = "Box - Front"
NORTH_AMERICA = ("North America", "United States", "World")


class Counter(xml.sax.ContentHandler):
    def __init__(self):
        self.stack = []
        self.text = []
        self.fields = {}
        self.games = {}          # database id -> the app's platform id
        self.with_box = set()
        self.with_box_here = set()

    def startElement(self, name, attrs):
        self.stack.append(name)
        self.text = []
        if name in ("Game", "GameImage"):
            self.fields = {}

    def characters(self, content):
        if self.stack:
            self.text.append(content)

    def endElement(self, name):
        if name in ("Game", "GameImage"):
            if name == "Game":
                database_id = self.fields.get("DatabaseID", "")
                platform = self.fields.get("Platform", "")
                if database_id and platform in PLATFORMS:
                    self.games[database_id] = platform
            elif self.fields.get("Type") == BOX_FRONT and self.fields.get("DatabaseID"):
                database_id = self.fields["DatabaseID"]
                self.with_box.add(database_id)
                if self.fields.get("Region") in NORTH_AMERICA:
                    self.with_box_here.add(database_id)
        if self.stack:
            value = "".join(self.text).strip()
            self.stack.pop()
            if self.stack:
                self.fields[name] = value
            self.text = []


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: launchbox_box_front.py Metadata.zip", file=sys.stderr)
        return 2
    counter = Counter()
    with zipfile.ZipFile(sys.argv[1]) as dump:
        with dump.open("Metadata.xml") as metadata:
            xml.sax.parse(metadata, counter)

    per_platform = collections.defaultdict(lambda: [0, 0, 0])
    for database_id, platform in counter.games.items():
        counts = per_platform[PLATFORMS[platform]]
        counts[0] += 1
        counts[1] += database_id in counter.with_box
        counts[2] += database_id in counter.with_box_here

    print("platform\tgames\tbox_front\tpct\tnorth_america_or_world_pct")
    for platform, (games, box, here) in sorted(per_platform.items(), key=lambda row: -row[1][0]):
        print(f"{platform}\t{games}\t{box}\t{100 * box / games:.1f}\t{100 * here / games:.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
