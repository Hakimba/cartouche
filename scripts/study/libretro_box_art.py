#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""How much of Cartouche's own game list libretro's box art answers.

https://thumbnails.libretro.com/ is a plain directory tree, one folder per system, with
`Named_Boxarts` holding one image per game, named after the reference lists the app already uses
(No-Intro for cartridges, Redump for discs). Nothing is searched and nothing is spent: either a name
is in the folder or it is not.

One line per platform with a title list in this repository: how many images the folder holds, how
many names the app's list holds, and how many of those names a normalised comparison finds.

    scripts/study/libretro_box_art.py > boxart.tsv

Fetches one listing per platform (about 2 MB each) and reads `app/data/titles/<platform>.tsv`. The
normalisation is the one the app's matching uses in spirit — lower case, no accents, letters and
digits only — so it is a little kinder than an exact comparison and a little stricter than a search.
"""
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THUMBNAILS = "https://thumbnails.libretro.com/"

# The app's platform id -> the system's folder in the tree.
SYSTEMS = {
    "nes": "Nintendo - Nintendo Entertainment System",
    "snes": "Nintendo - Super Nintendo Entertainment System",
    "n64": "Nintendo - Nintendo 64",
    "gb": "Nintendo - Game Boy",
    "gbc": "Nintendo - Game Boy Color",
    "gba": "Nintendo - Game Boy Advance",
    "nds": "Nintendo - Nintendo DS",
    "3ds": "Nintendo - Nintendo 3DS",
    "gc": "Nintendo - GameCube",
    "wii": "Nintendo - Wii",
    "switch": "Nintendo - Nintendo Switch",
    "psx": "Sony - PlayStation",
    "ps2": "Sony - PlayStation 2",
    "psp": "Sony - PlayStation Portable",
    "psvita": "Sony - PlayStation Vita",
    "genesis": "Sega - Mega Drive - Genesis",
    "master": "Sega - Master System - Mark III",
    "gamegear": "Sega - Game Gear",
    "dreamcast": "Sega - Dreamcast",
    "saturn": "Sega - Saturn",
    "segacd": "Sega - Mega-CD - Sega CD",
    "atari2600": "Atari - 2600",
    "tg16": "NEC - PC Engine - TurboGrafx 16",
    "xbox": "Microsoft - Xbox",
    "xbox360": "Microsoft - Xbox 360",
}


def folded(name: str) -> str:
    """A name reduced to the letters and digits it is compared on."""
    plain = unicodedata.normalize("NFKD", name)
    plain = "".join(letter for letter in plain if not unicodedata.combining(letter))
    return re.sub(r"[^a-z0-9]+", "", plain.lower())


def titles(platform: str) -> list[str]:
    """The game names the platform's reference list holds."""
    listing = ROOT / "app" / "data" / "titles" / f"{platform}.tsv"
    if not listing.exists():
        return []
    return [
        line.split("\t")[0]
        for line in listing.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    ]


def box_arts(system: str) -> list[str] | None:
    """The image names in the system's box art folder, or none when the folder cannot be read."""
    listing = THUMBNAILS + urllib.parse.quote(system) + "/" + urllib.parse.quote("Named_Boxarts") + "/"
    try:
        page = urllib.request.urlopen(listing, timeout=90).read().decode("utf-8", "ignore")
    except OSError:
        return None
    names = [urllib.parse.unquote(href) for href in re.findall(r'href="([^"?/][^"]*)"', page)]
    return [name for name in names if name.lower().endswith((".png", ".jpg", ".jpeg"))]


def main() -> int:
    print("platform\tboxarts\ttitles\tmatched\tpct", flush=True)
    for platform, system in SYSTEMS.items():
        names = titles(platform)
        arts = box_arts(system)
        if not names or arts is None:
            print(f"{platform}\t\t\t\t", flush=True)
            continue
        known = {folded(art.rsplit(".", 1)[0]) for art in arts}
        matched = sum(1 for name in names if folded(name) in known)
        print(f"{platform}\t{len(arts)}\t{len(names)}\t{matched}\t{100 * matched / len(names):.1f}", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
