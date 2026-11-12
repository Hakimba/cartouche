#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The list of specialized pipelines the engine template compiles ahead (docs/README.md, "The engine template").

A build exported with rendering/shader_compiler/ubershaders/print_specialized_pipelines=true prints one
"Specialized pipeline:" line of twelve numbers for each pipeline it draws with. This script gathers those lines
from logs into the setting rendering/shader_compiler/ubershaders/specialized_pipelines of app/project.godot.

Usage: scripts/specialized_pipelines.py show LOG...    the pipelines of the logs, decoded
       scripts/specialized_pipelines.py write LOG...   app/project.godot lists the pipelines of the logs
       scripts/specialized_pipelines.py check LOG...   fails when a log holds a pipeline app/project.godot does not list
       scripts/specialized_pipelines.py listed         fails when ubershaders are off and the list is empty or cut
"""
import pathlib
import re
import sys

PROJECT = pathlib.Path(__file__).resolve().parent.parent / "app" / "project.godot"
SETTING = "shader_compiler/ubershaders/specialized_pipelines"
WORDS = 12
LINE = re.compile(r"Specialized pipeline:((?: -?\d+){%d})\s*$" % WORDS)
LISTED = re.compile(r"^%s=PackedInt32Array\(([^)]*)\)\n" % re.escape(SETTING), re.M)
UBERSHADERS_OFF = re.compile(r"^shader_compiler/ubershaders/enabled=false$", re.M)
# The samples word of 4x, the default edge smoothing.
PROJECT_SAMPLES = 2
CULL = ["off", "front", "back"]
COUNT = ["0", "1", "n"]


def printed(logs):
    """The pipelines printed in the logs, each once, sorted."""
    found = set()
    for log in logs:
        for line in pathlib.Path(log).read_text(errors="replace").splitlines():
            match = LINE.search(line)
            if match:
                found.add(at_project_samples(tuple(int(word) for word in match.group(1).split())))
    return sorted(found)


def at_project_samples(pipeline):
    """A pipeline drawn at the project's edge smoothing is compiled at whichever the user chose: the engine does not
    read the samples it was printed with, written here as the default's so that a run at 2x gives the same list."""
    return pipeline[:5] + (PROJECT_SAMPLES,) + pipeline[6:] if pipeline[6] & 4 else pipeline


def listed_words(text):
    match = LISTED.search(text)
    return [int(word) for word in match.group(1).split(",") if word.strip()] if match else []


def listed():
    """The pipelines app/project.godot lists."""
    words = listed_words(PROJECT.read_text())
    return sorted({tuple(words[i:i + WORDS]) for i in range(0, len(words) - WORDS + 1, WORDS)})


def whole():
    """With ubershaders off and no list, every pipeline is compiled in the frame that first draws with it; a cut list
    loses its last pipeline (the engine ignores the tail)."""
    text = PROJECT.read_text()
    count = len(listed_words(text))
    if count % WORDS:
        sys.exit("app/project.godot lists %d numbers, not a whole number of pipelines of %d" % (count, WORDS))
    if not count and UBERSHADERS_OFF.search(text):
        sys.exit("app/project.godot turns ubershaders off and lists no pipeline: record the list "
                 "(docs/README.md, The engine template)")
    print("%d pipelines listed" % (count // WORDS))


def decoded(pipeline):
    shader, low, high, surface, version, samples, target, cull, packed_0, packed_1, _, render_pass = pipeline
    lights = packed_1 & 0xFFFFFFFF
    return ("shader %08x format %08x%08x %s version %d samples %s%s %s cull %s omni %s spot %s sun %s "
            "packed_0 %08x pass %d") % (
        shader & 0xFFFFFFFF, high & 0xFFFFFFFF, low & 0xFFFFFFFF, "instanced" if surface & 256 else "plain", version,
        1 << samples, " (project)" if target & 4 else "", "subpass" if target & 1 else "separate", CULL[cull],
        COUNT[(lights >> 12) & 3], COUNT[(lights >> 14) & 3], COUNT[(lights >> 20) & 3], packed_0 & 0xFFFFFFFF,
        render_pass)


def write(pipelines):
    text = LISTED.sub("", PROJECT.read_text())
    line = "%s=PackedInt32Array(%s)\n" % (SETTING, ", ".join(str(word) for pipeline in pipelines for word in pipeline))
    marker = "[rendering]\n\n"
    assert marker in text, "app/project.godot has no [rendering] section"
    PROJECT.write_text(text.replace(marker, marker + line, 1) if pipelines else text)


def main(arguments):
    if arguments == ["listed"]:
        whole()
        return
    if len(arguments) < 2 or arguments[0] not in ("show", "write", "check"):
        sys.exit(__doc__)
    pipelines = printed(arguments[1:])
    if arguments[0] == "show":
        for pipeline in pipelines:
            print(decoded(pipeline))
    elif arguments[0] == "write":
        write(pipelines)
    else:
        missing = sorted(set(pipelines) - set(listed()))
        for pipeline in missing:
            print("not listed: " + decoded(pipeline))
        if missing:
            sys.exit(1)
    print("%d pipelines" % len(pipelines))


main(sys.argv[1:])
