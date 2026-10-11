#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Derives a console's launch steps (its folder's launch.json, described in docs/ONBOARDING.md)
from a set of steps tuned outside the app and exported as JSON: a `choiceStep` index, its `steps`,
each step's console under the key `--console-key` names and its moving parts under `parts`, and
`model_hash`, the `hash` of the console's model.json (dev/export_console.sh) they were tuned on.

Refuses steps tuned on another model than the folder's: their hash is compared with the one the
console's export gives now (Godot runs, as for dev/export_console.sh). Keeps what the app plays: the
step the game is chosen at, and each step's timing and state, with the model's hash. Drops names,
notes, the camera (the carousel's stays) and the art bar's own presence (it follows the pill).
`--order` lists the exported steps in the order to play them. `--blur-width` is the width, in
pixels, of the screen the blur was tuned on: the app's blur is in pixels of its own 1280 wide
screen. A `lid` group, as steps tuned before parts had names, moves the PS2 slim's `lid_degrees`.

Usage: dev/launch_steps.py steps.json --console ps2_slim --console-key ps2 [--order 1,0,2,...]
    [--blur-width 868]
writes app/carousel/consoles/<console>/launch.json.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

PLAYED = ("dur", "ease", "hold", "parts", "disc", "row", "consoles", "look", "ui", "fx")
SCREEN_WIDTH = 1280
DEV = Path(__file__).resolve().parent
CONSOLES = DEV.parent / "app" / "carousel" / "consoles"

parser = argparse.ArgumentParser()
parser.add_argument("steps")
parser.add_argument("--console", required=True, help="the console's folder, under app/carousel/consoles")
parser.add_argument("--console-key", required=True, help="the key of each step's console")
parser.add_argument("--order", help="comma-separated indexes of the exported steps")
parser.add_argument("--blur-width", type=float, default=SCREEN_WIDTH)
args = parser.parse_args()
folder = CONSOLES / args.console
if not (folder / "console.tres").is_file():
    parser.error(f"no console folder {folder}")
with open(args.steps, encoding="utf-8") as file:
    exported = json.load(file)
version = exported.get("data", exported)
steps = version["steps"]
order = [int(i) for i in args.order.split(",")] if args.order else list(range(len(steps)))
if version["choiceStep"] not in order:
    parser.error(f"--order leaves out the step the game is chosen at ({version['choiceStep']})")
with tempfile.TemporaryDirectory() as out_dir:
    subprocess.run([DEV / "export_console.sh", args.console, out_dir], check=True, stdout=subprocess.DEVNULL)
    with open(Path(out_dir) / f"{args.console}.model.json", encoding="utf-8") as file:
        model_hash = json.load(file)["hash"]
if version.get("model_hash") != model_hash:
    parser.error(f"steps tuned on another model than {args.console}'s (hash {version.get('model_hash')}, "
                 f"the model's now {model_hash}): export it again and tune them on it")


def played(step):
    if "lid" in step:
        step = dict(step, parts={"lid_degrees": step["lid"]["angle"]})
    kept = {key: step[key] for key in PLAYED if key in step}
    kept["console"] = step[args.console_key]
    kept["ui"] = {key: value for key, value in kept.get("ui", {}).items() if key != "progress"}
    look = kept.get("look", {})
    if "blur" in look:
        kept["look"] = dict(look, blur=round(look["blur"] * SCREEN_WIDTH / args.blur_width, 3))
    return kept


with open(folder / "launch.json", "w", encoding="utf-8") as file:
    json.dump({"model_hash": model_hash, "choice": order.index(version["choiceStep"]),
               "steps": [played(steps[i]) for i in order]}, file, indent=1)
    file.write("\n")
