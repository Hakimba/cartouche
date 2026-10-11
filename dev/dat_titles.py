#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Derives app/data/titles/<platform>.tsv from a libretro-database DAT (clrmamepro format): Redump's
for disc platforms, No-Intro's for cartridges, both naming games the same way.

One line per game image name: `name<TAB>serials`, serials comma-separated, sorted by name. Only
what the library needs is kept (regions are in the names; no hashes or sizes), which makes the file
several times smaller than the DAT.

Usage: dev/dat_titles.py "Sony - PlayStation 2.dat" > app/data/titles/ps2.tsv
       dev/dat_titles.py "Nintendo - Game Boy Advance.dat" > app/data/titles/gba.tsv
The DATs come from https://github.com/libretro/libretro-database (metadat/redump, metadat/no-intro).
"""
import re
import sys

GAME = re.compile(r'^game \($(.*?)^\)$', re.M | re.S)
FIELD = re.compile(r'^\t(name|serial) "(.*)"$', re.M)
# Some PlayStation entries repeat a serial with a disc suffix (SLPM-65002-0): the plain serial is enough.
SUFFIXED = re.compile(r'^([A-Z]{4}-\d{5})-\d+$')

titles: dict[str, set[str]] = {}
with open(sys.argv[1], encoding="utf-8") as dat:
    text = dat.read()
for game in GAME.finditer(text):
    fields = dict(FIELD.findall(game.group(1)))
    serials = titles.setdefault(fields["name"], set())
    if fields.get("serial"):
        serials.update(SUFFIXED.sub(r"\1", s.strip()) for s in fields["serial"].split(","))
for name in sorted(titles):
    print(f"{name}\t{','.join(sorted(titles[name]))}")
