#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Each QA check of sfx.py against a sound made to have its defect, and a clean sound passing them all.

    python3 scripts/audio/test_sfx.py

The signals are made here, to test the checks only: none of them is ever a sound of the app.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sfx  # noqa: E402

R = sfx.RATE
ROLE = {"loudness": 0.0, "max_s": 0.12, "max_attack_ms": 10, "max_low_share": 0.15}
random = np.random.default_rng(1)


def click(ms: float = 60, decay_ms: float = 12, rate: int = R) -> np.ndarray:
    n = signal.lfilter(*signal.butter(2, [800 / (rate / 2), 6000 / (rate / 2)], "band"), random.standard_normal(int(ms * rate / 1000)))
    return n / np.abs(n).max() * np.exp(-np.arange(len(n)) / rate / (decay_ms / 1000))


def faded(x: np.ndarray) -> np.ndarray:
    n = int(sfx.FADE_OUT_S * R)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x * 0.5


def write(folder: Path, name: str, x: np.ndarray, rate: int = R, subtype: str = "int16") -> Path:
    path = folder / name
    data = np.clip(x, -1, 1)
    wavfile.write(path, rate, (data * 32767).astype(np.int16) if subtype == "int16" else data.astype(np.float32))
    return path


def fails(folder: Path, name: str, x: np.ndarray, **written: object) -> list[str]:
    m = sfx.measure(write(folder, name, x, **written))
    role = dict(ROLE, loudness=round(sfx.loudness(sfx.decode(folder / name)), 1))
    return sfx.verdict(m, role)


def main() -> None:
    problems = []

    def expect(case: str, found: list[str], wanted: str | None) -> None:
        caught = [f for f in found if wanted and wanted in f]
        ok = not found if wanted is None else bool(caught)
        print(f"{'ok  ' if ok else 'FAIL'} {case}: {'; '.join(found) or 'passes'}")
        if not ok:
            problems.append(case)

    with tempfile.TemporaryDirectory() as tmp:
        folder = Path(tmp)
        good = faded(click())
        expect("clean click", fails(folder, "good.wav", good), None)
        expect("5 ms of silence first", fails(folder, "lead.wav", np.concatenate([np.zeros(int(0.005 * R)), good])), "lead silence")
        second = faded(np.concatenate([click(30, 3), 10 ** (-30 / 20) * click(30, 3)]))
        expect("a second click 30 dB down", fails(folder, "second.wav", second), "events")
        close = faded(np.concatenate([click(20, 3), click(40, 3)]))
        expect("two clicks 20 ms apart", fails(folder, "close.wav", close), "events")
        t = np.arange(int(0.11 * R)) / R
        chord = sum(np.sin(2 * np.pi * f * t) for f in (523.0, 548.0, 659.0, 784.0, 806.0)) * np.exp(-t / 0.08)
        chord = faded(chord / np.abs(chord).max())
        expect("a chord beating", fails(folder, "chord.wav", chord), None)
        soft = dict(ROLE, max_bright_hz=1300, max_crest_db=18)
        m = sfx.measure(write(folder, "bright.wav", good))
        expect("a bright sharp click where soft is asked", sfx.verdict(m, dict(soft, loudness=round(m["loudness"], 1))), "bright")
        tick = faded(sfx.tone({"hz": [800, 600], "decay_ms": 7, "length": 0.05}))
        m = sfx.measure(write(folder, "tick.wav", tick))
        print(f"{'ok  ' if m['events'] == 1 else 'FAIL'} a pure tick is one event: {m['events']}")
        if m["events"] != 1:
            problems.append("a pure tick")
        expect("two pure ticks", fails(folder, "ticks.wav", faded(np.concatenate([tick[:1200], tick]))), "events")
        cut = good.copy()
        cut[-30:] = 0.3
        expect("a click at the end", fails(folder, "end.wav", cut), "click at the end")
        expect("too hot", fails(folder, "hot.wav", good / np.abs(good).max() * 0.999), "peak")
        low = faded(click() + 2 * np.sin(2 * np.pi * 120 * np.arange(len(good)) / R) * np.exp(-np.arange(len(good)) / R / 0.03))
        expect("energy under 300 Hz", fails(folder, "low.wav", low), "under 300 Hz")
        expect("120 ms long", fails(folder, "long.wav", faded(click(120))), "duration")
        expect("stereo", fails(folder, "stereo.wav", np.stack([good, good], axis=1)), "channels")
        expect("44.1 kHz", fails(folder, "rate.wav", signal.resample_poly(good, 147, 160), rate=44100), "Hz")
        subprocess.run(["sox", str(write(folder, "short.wav", good)), str(folder / "short.ogg")], check=True)
        m = sfx.measure(folder / "short.ogg")
        expect("an OGG under 150 ms", sfx.verdict(m, dict(ROLE, loudness=round(m["loudness"], 1))), "WAV under")

    # A validated sound's recipe, changed by a hair, no longer matches its lock.
    config = sfx.load_json("sounds.json")
    for name, validated in config.get("validated", {}).items():
        locked = sfx.recipe_sha256(config, name) == validated["recipe_sha256"]
        config["sounds"][name]["length"] += 0.001
        caught = sfx.recipe_sha256(config, name) != validated["recipe_sha256"]
        print(f"{'ok  ' if locked and caught else 'FAIL'} {name}, validated, is locked")
        if not (locked and caught):
            problems.append(f"{name}'s lock")
    print("all checks catch their defect" if not problems else f"{len(problems)} problems: {', '.join(problems)}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
