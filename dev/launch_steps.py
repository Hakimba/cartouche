#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Derives a console's launch steps (app/data/launch/<console>.json, described in
docs/ONBOARDING.md) from a set of steps tuned outside the app and exported as JSON: a
`choiceStep` index and its `steps`, each step's console under the key `--console-key` names.

Keeps what the app plays: the step the game is chosen at, and each step's timing and state. Drops
names, notes, the camera (the carousel's stays) and the art bar's own presence (it follows the
pill). `--order` lists the exported steps in the order to play them. `--blur-width` is the width,
in pixels, of the screen the blur was tuned on: the app's blur is in pixels of its own 1280 wide
screen.

Usage: dev/launch_steps.py steps.json [--order 1,0,2,...] [--blur-width 868] [--console-key ps2]
    > app/data/launch/ps2_slim.json
"""
import argparse
import json

PLAYED = ("dur", "ease", "hold", "lid", "disc", "row", "consoles", "look", "ui", "fx")
SCREEN_WIDTH = 1280

parser = argparse.ArgumentParser()
parser.add_argument("steps")
parser.add_argument("--order", help="comma-separated indexes of the exported steps")
parser.add_argument("--blur-width", type=float, default=SCREEN_WIDTH)
parser.add_argument("--console-key", default="ps2", help="the key of each step's console")
args = parser.parse_args()
with open(args.steps, encoding="utf-8") as file:
    exported = json.load(file)
version = exported.get("data", exported)
steps = version["steps"]
order = [int(i) for i in args.order.split(",")] if args.order else list(range(len(steps)))
if version["choiceStep"] not in order:
    parser.error(f"--order leaves out the step the game is chosen at ({version['choiceStep']})")


def played(step):
    kept = {key: step[key] for key in PLAYED if key in step}
    kept["console"] = step[args.console_key]
    kept["ui"] = {key: value for key, value in kept.get("ui", {}).items() if key != "progress"}
    look = kept.get("look", {})
    if "blur" in look:
        kept["look"] = dict(look, blur=round(look["blur"] * SCREEN_WIDTH / args.blur_width, 3))
    return kept


print(json.dumps({"choice": order.index(version["choiceStep"]),
                  "steps": [played(steps[i]) for i in order]}, indent=1))
