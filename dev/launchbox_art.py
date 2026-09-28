#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Derives app/data/art/<platform>.tsv from the LaunchBox Games Database dump (Metadata.zip).

One line per game: `name<TAB>alternate names<TAB>discs`. Alternate names are
separated by `|`; discs are `region=file` pairs separated by `;`, the region empty when the database
names none, the file relative to https://images.launchbox-app.com/. Fan-made images are left out. The first line,
`# <date>`, is the dump's date: games found in no source are looked up again once it changes.

Usage: dev/launchbox_art.py Metadata.zip "Sony Playstation 2" > app/data/art/ps2.tsv
The dump comes from https://gamesdb.launchbox-app.com/Metadata.zip (about 100 MB, updated daily).
"""
import datetime
import sys
import xml.etree.ElementTree as ElementTree
import zipfile



def clean(text: str) -> str:
    return " ".join((text or "").split())


def extract(archive: str, platform: str) -> None:
    names: dict[str, str] = {}
    alternates: dict[str, list[str]] = {}
    discs: dict[str, list[str]] = {}
    with zipfile.ZipFile(archive) as dump:
        dated = datetime.date(*dump.getinfo("Metadata.xml").date_time[:3])
        with dump.open("Metadata.xml") as metadata:
            for _, element in ElementTree.iterparse(metadata):
                database_id = element.findtext("DatabaseID") or ""
                if database_id and element.tag == "Game" and element.findtext("Platform") == platform:
                    names[database_id] = clean(element.findtext("Name"))
                elif database_id and element.tag == "GameAlternateName":
                    alternates.setdefault(database_id, []).append(clean(element.findtext("AlternateName")))
                elif database_id and element.tag == "GameImage" and element.findtext("Type") == "Disc":
                    discs.setdefault(database_id, []).append(f"{clean(element.findtext('Region'))}={element.findtext('FileName')}")
                if element.tag in ("Game", "GameAlternateName", "GameImage"):
                    element.clear()

    print(f"# {dated.isoformat()}")
    lines = []
    for database_id, name in names.items():
        # A game without a scan stays: a title it shares with another makes that title name no game.
        if not name:
            continue
        others = sorted({a for a in alternates.get(database_id, []) if a and a != name and "|" not in a})
        lines.append("\t".join([name, "|".join(others), ";".join(sorted(discs.get(database_id, [])))]))
    print("\n".join(sorted(lines)))


if __name__ == "__main__":
    extract(sys.argv[1], sys.argv[2])
