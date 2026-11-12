#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Whether every console's plinth picture is the picture of the console as it is now.

scripts/bake_plinths.sh draws app/carousel/consoles/<folder>/plinth.png and plinth_2x.png from the console's model, its pose on the
plinth (app/data/turntable.json) and its plinth lights (app/data/studio_lights.json). This script records what each
picture was drawn from, in scripts/plinths.json, and tells when a picture is older than what it shows.

Usage: scripts/plinths.py write   records what the pictures were just drawn from (scripts/bake_plinths.sh runs it)
       scripts/plinths.py check   fails when a console has no picture, or a model, pose or light changed since
"""
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONSOLES = ROOT / "app" / "carousel" / "consoles"
RECORD = ROOT / "scripts" / "plinths.json"
PICTURES = ("plinth.png", "plinth_2x.png")


def drawn_from():
    """Each console folder with the hash of what its picture shows."""
    poses = json.loads((ROOT / "app" / "data" / "turntable.json").read_text())["consoles"]
    lights = json.loads((ROOT / "app" / "data" / "studio_lights.json").read_text())
    found = {}
    for folder in sorted(path.parent for path in CONSOLES.glob("*/console.tres")):
        seen = hashlib.sha256()
        for part in sorted(folder.iterdir()):
            if part.is_file() and not part.name.startswith("plinth") and part.suffix not in (".import", ".uid"):
                seen.update(part.name.encode() + part.read_bytes())
        rig = lights["lights"].get(folder.name, {}).get("plinth", lights["today"])
        seen.update(json.dumps([poses.get(folder.name, {}), rig], sort_keys=True).encode())
        found[folder.name] = seen.hexdigest()[:16]
    return found


def main():
    if sys.argv[1:] == ["write"]:
        RECORD.write_text(json.dumps(drawn_from(), indent=2) + "\n")
        return 0
    if sys.argv[1:] != ["check"]:
        print(__doc__, file=sys.stderr)
        return 2
    recorded = json.loads(RECORD.read_text()) if RECORD.exists() else {}
    stale = [folder for folder, seen in drawn_from().items()
             if recorded.get(folder) != seen or not all((CONSOLES / folder / picture).exists() for picture in PICTURES)]
    for folder in stale:
        print(f"{folder}: its plinth picture is missing or older than its model, pose or lights", file=sys.stderr)
    if stale:
        print("run scripts/bake_plinths.sh and commit the pictures with scripts/plinths.json", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
