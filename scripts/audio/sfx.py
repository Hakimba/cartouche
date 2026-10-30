#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""The app's sound effects, made in code from pure tones, to the files Godot plays.

    scripts/audio/sfx.py render        make every sound (sounds.json `sounds`) into app/audio/sfx, the sound each of
                                   the app's cues plays (`cues`) into app/audio/cues.json, the candidates to try
                                   on the sound board into app/audio/candidates, and the board's data (families,
                                   verdicts, the screens and their gestures) into app/audio/test/board.json
    scripts/audio/sfx.py qa            measure every sound against its role, draw its spectrogram and waveform
    scripts/audio/sfx.py map           write build/sound-map/index.html: every screen, its gestures and the sound each
                                   plays, to listen to in a browser

Needs ffmpeg (or FFMPEG=path), sox, and Python's numpy, scipy and Pillow. QA pictures and the report land in
app/audio/qa. The thresholds are the roles' in sounds.json; a sound that misses one fails, and a threshold is never
relaxed. `qa` exits 1 when a sound fails.
"""

import hashlib
import html
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SFX = ROOT / "app" / "audio" / "sfx"
CANDIDATES = ROOT / "app" / "audio" / "candidates"
QA = ROOT / "app" / "audio" / "qa"
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
RATE = 48000
# Shorter sounds are kept as WAV: decoding an OGG adds latency to the first frame.
WAV_UNDER_S = 0.15
# Every sound ends on this fade, against a click; a note may decay longer before it (`decay_s`).
FADE_OUT_S = 0.008
LAYER_FADE_S = 0.005
LAYER_ONSET_DB = -20.0
# Under the speakers' reach, what is left of a mix only costs their excursion.
MIX_HIGHPASS_HZ = 250
# The sound starts where it first reaches this far under its peak; its attack, where it comes within
# ATTACK_DB of it.
ONSET_DB = -30.0
ATTACK_DB = -10.0
# Loudness: K-weighted (ITU-R BS.1770) energy over the loudest window of this length; ungated, as
# most sounds are shorter than the 400 ms blocks of integrated loudness.
LOUDNESS_WINDOW_S = 0.1
LOW_HZ = 300.0
# What lies this far under the peak is not heard: no event, no click, no background that matters.
AUDIBLE_DB = 40.0
# An event starts where most of the spectrum rises at once: at least half the bands from 300 Hz to
# 16 kHz up this much within 2 ms (notes beating against each other move a few partials only); or, for a
# pure tone, which rises on its own line, where the whole level jumps ONSET_JUMP_DB within 2 ms.
ONSET_RISE_DB = 6.0
ONSET_SHARE = 0.5
ONSET_JUMP_DB = 15.0
# Attacks closer than this are one event.
EVENT_GAP_S = 0.015
# ITU-R BS.1770 K-weighting at 48 kHz: high shelf, then high pass.
_K_SHELF = ([1.53512485958697, -2.69169618940638, 1.19839281085285], [1.0, -1.69065929318241, 0.73248077421585])
_K_HIGH = ([1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621])


def load_json(name: str) -> dict:
    return json.loads((HERE / name).read_text())


def decode(path: Path) -> np.ndarray:
    """Mono at 48 kHz, as every sound is made and played."""
    raw = subprocess.run([FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def db(value: float) -> float:
    return 20.0 * np.log10(max(value, 1e-12))


def loudness(x: np.ndarray) -> float:
    k = signal.lfilter(*_K_HIGH, signal.lfilter(*_K_SHELF, x))
    window = int(LOUDNESS_WINDOW_S * RATE)
    padded = np.pad(k * k, (0, max(0, window - len(k))))
    energy = np.convolve(padded, np.ones(window) / window, mode="valid").max()
    return -0.691 + 10.0 * np.log10(max(energy, 1e-12))


def true_peak(x: np.ndarray) -> float:
    return db(np.abs(signal.resample_poly(x, 4, 1)).max())


def onset(x: np.ndarray, under_peak_db: float = ONSET_DB) -> int:
    """The last zero crossing before the signal first reaches [under_peak_db] below its peak."""
    first = int(np.argmax(np.abs(x) >= np.abs(x).max() * 10 ** (under_peak_db / 20)))
    crossings = np.nonzero(np.signbit(x[:first + 1][1:]) != np.signbit(x[:first + 1][:-1]))[0]
    return int(crossings[-1] + 1) if len(crossings) else first


def envelope_db(x: np.ndarray, window_s: float, hop_s: float) -> np.ndarray:
    window, hop = int(window_s * RATE), int(hop_s * RATE)
    frames = [x[i:i + window] for i in range(0, max(1, len(x) - window + 1), hop)]
    return np.array([db(np.sqrt(np.mean(f * f))) for f in frames])


def attacks(x: np.ndarray) -> list[float]:
    """Seconds where an event starts (see ONSET_RISE_DB), down to AUDIBLE_DB under the loudest moment."""
    frame, hop = int(0.004 * RATE), int(0.001 * RATE)
    padded = np.concatenate((np.zeros(frame), x))
    starts = range(0, len(padded) - frame + 1, hop)
    spectra = np.array([np.abs(np.fft.rfft(padded[i:i + frame] * np.hanning(frame))) for i in starts])
    hz = np.fft.rfftfreq(frame, 1 / RATE)
    bands = spectra[:, (hz >= LOW_HZ) & (hz <= 16000)] ** 2
    level = 10 * np.log10(bands.sum(axis=1) + 1e-20)
    bins = 10 * np.log10(bands + 1e-20)
    # A band counts when it rises and stands within reach of the frame's loudest band.
    rising = (bins[2:] - bins[:-2] >= ONSET_RISE_DB) & (bins[2:] >= bins[2:].max(axis=1, keepdims=True) - AUDIBLE_DB)
    found = []
    jumps = level[2:] - level[:-2] >= ONSET_JUMP_DB
    for t in np.flatnonzero(((rising.mean(axis=1) >= ONSET_SHARE) | jumps) & (level[2:] >= level.max() - AUDIBLE_DB)):
        at = (t + 2) * hop / RATE - frame / RATE
        if not found or at - found[-1] > EVENT_GAP_S:
            found.append(max(0.0, at))
    return found


# render

def sox(*args: str) -> None:
    subprocess.run(["sox", "-V1", *args], check=True)


def tone(spec: dict) -> np.ndarray:
    """A pure tone gliding from `hz[0]` to `hz[1]` (exponentially) over `length` seconds, dying away with a time
    constant of `decay_ms`, with `partials` as [multiple, dB] pairs: a recording always kept some texture the user's
    ear refused, a tone none."""
    t = np.arange(int(spec["length"] * RATE)) / RATE
    start, end = spec["hz"]
    hz = start * (end / start) ** (t / spec["length"])
    phase = 2 * np.pi * np.cumsum(hz) / RATE
    wave = np.sin(phase) + sum(10 ** (gain / 20) * np.sin(k * phase) for k, gain in spec.get("partials", []))
    return wave * np.exp(-t / (spec["decay_ms"] / 1000)) * 0.5


def render_layer(layer: dict, out: Path) -> None:
    """One tone made, then filtered."""
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "source.wav"
        wavfile.write(wav, RATE, tone(layer["tone"]).astype(np.float32))
        effects = []
        for hz in layer.get("highpass", []):
            effects += ["highpass", str(hz)]
        if "lowpass" in layer:
            effects += ["lowpass", str(layer["lowpass"])]
        cut = Path(tmp) / "cut.wav"
        sox(str(wav), "-b", "32", "-e", "floating-point", str(cut), *effects)
        # Layers meet on their attacks (a quiet lead-in left out), [delay] after it when given; a hit rounded off
        # over [soften_s] (a finger sinking into a cushion rather than striking it). Each one from the same peak:
        # its gain is its balance against the others. Cut short, it fades rather than stops dead.
        sox(str(cut), "-b", "32", "-e", "floating-point", str(out), "trim", f"{onset(decode(cut), LAYER_ONSET_DB)}s",
            "pad", str(layer.get("delay", 0.0)), "fade", "q", str(layer.get("soften_s", 0.0)), "-0", str(LAYER_FADE_S),
            "norm", "-12", "gain", str(layer.get("gain_db", 0.0)))


def entries(config: dict) -> list[tuple[str, dict, Path]]:
    """Every sound to make: the app's, then the candidates for one, each with its folder."""
    return [(name, sound, SFX) for name, sound in config["sounds"].items()] + \
        [(name, sound, CANDIDATES) for name, sound in config.get("candidates", {}).items()]


def sound_path(name: str, folder: Path = SFX) -> Path:
    """The file of sound [name]: its WAV, else its OGG."""
    wav = folder / f"{name}.wav"
    return wav if wav.exists() else folder / f"{name}.ogg"


def render_sound(name: str, sound: dict, role: dict, folder: Path = SFX) -> Path:
    with tempfile.TemporaryDirectory() as tmp:
        layers = []
        for i, layer in enumerate(sound["layers"]):
            layers.append(Path(tmp) / f"layer{i}.wav")
            render_layer(layer, layers[-1])
        mixed = Path(tmp) / "mixed.wav"
        if len(layers) > 1:
            sox("-m", *map(str, layers), "-b", "32", "-e", "floating-point", str(mixed))
        else:
            mixed = layers[0]
        x = decode(mixed)
        start = onset(x)
        length = min((len(x) - start) / RATE, sound.get("length", role["max_s"]))
        samples = int(length * RATE)
        shaped = Path(tmp) / "shaped.wav"
        # The decay first (a note shortened gracefully), then the fade against a click.
        sox(str(mixed), "-b", "32", "-e", "floating-point", str(shaped), "trim", f"{start}s", f"{samples}s",
            "highpass", str(MIX_HIGHPASS_HZ), "fade", "q", "0", f"{samples}s", str(sound.get("decay_s", FADE_OUT_S)),
            "fade", "t", "0", f"{samples}s", str(FADE_OUT_S))
        gain = f"{role['loudness'] - loudness(decode(shaped)):.3f}"
        out = folder / f"{name}.{'wav' if length < WAV_UNDER_S else 'ogg'}"
        # The other format goes, with its import; this one's import stays, and its uid with it.
        other = out.with_suffix(".ogg" if out.suffix == ".wav" else ".wav")
        for stale in (other, other.with_name(other.name + ".import")):
            stale.unlink(missing_ok=True)
        if out.suffix == ".wav":
            sox(str(shaped), "-b", "16", str(out), "gain", gain, "dither")
        else:
            # Vorbis does not end exactly on the faded zero: a few milliseconds of silence take its error. Its
            # encoding moves the loudness a little: measured on the file, corrected once.
            sox(str(shaped), "-C", "6", str(out), "gain", gain, "pad", "0", "0.005")
            off = role["loudness"] - loudness(decode(out))
            if abs(off) > 0.2:
                sox(str(shaped), "-C", "6", str(out), "gain", f"{float(gain) + off:.3f}", "pad", "0", "0.005")
        return out


BOARD = ROOT / "app" / "audio" / "test" / "board.json"
# The user's verdict on a sound, by ear: validated, a good track still to work on, refused; else not yet.
STATUSES = ("validated", "promising", "refused", "untreated")


def board(config: dict) -> dict:
    """What the sound board shows: each sound's status and note (a sound validated is locked), its family and its
    name in the user's words, and every screen with its gestures, each with the cue it plays (`board` and `screens`
    in sounds.json: every sound in one family, every cue on some screen)."""
    found = {name: config.get("reviews", {}).get(name, {"status": "untreated", "note": ""}) for name in config["sounds"]}
    families = config["board"]
    grouped = [sound for _, sounds in families["categories"] for sound in sounds]
    if sorted(grouped) != sorted(config["sounds"]) or set(families["labels"]) != set(config["sounds"]):
        sys.exit("sounds.json: every sound in exactly one family of the board, with its label")
    shown = {cue for _, gestures in config["screens"] for _, cue in gestures}
    if shown != set(config["cues"]):
        sys.exit(f"sounds.json: cues on no screen {sorted(set(config['cues']) - shown)}, "
                 f"or gestures with an unknown cue {sorted(shown - set(config['cues']))}")
    if any(review["status"] not in STATUSES for review in found.values()):
        sys.exit(f"sounds.json: a review's status is none of {STATUSES}")
    if {n for n, r in found.items() if r["status"] == "validated"} != set(config.get("validated", {})):
        sys.exit("sounds.json: the sounds validated and the sounds locked differ")
    return {"sounds": found, "categories": families["categories"], "labels": families["labels"],
            "screens": config["screens"], "cues": config["cues"]}


CUES = ROOT / "app" / "audio" / "cues.json"


def cues(config: dict) -> dict:
    """The file of the system's sound each of the app's cues plays (`cues` in sounds.json), or none."""
    played = {sound for sound in config["cues"].values() if sound}
    if played - set(config["sounds"]) or set(config["sounds"]) - played:
        sys.exit(f"sounds.json: cues play sounds it has not {sorted(played - set(config['sounds']))}, "
                 f"or sounds no cue plays {sorted(set(config['sounds']) - played)}")
    return {cue: f"res://{sound_path(sound).relative_to(ROOT / 'app')}" if sound else ""
            for cue, sound in config["cues"].items()}


def render() -> None:
    config = load_json("sounds.json")
    BOARD.parent.mkdir(parents=True, exist_ok=True)
    BOARD.write_text(json.dumps(board(config), indent=1, ensure_ascii=False) + "\n")
    for name, sound, folder in entries(config):
        folder.mkdir(parents=True, exist_ok=True)
        out = render_sound(name, sound, config["roles"][sound["role"]], folder)
        print(f"{name:22} -> {out.relative_to(ROOT)}")
    CUES.write_text(json.dumps(cues(config), indent=1) + "\n")


# qa

def stream_format(path: Path) -> tuple[str, int, int]:
    """Codec, sample rate and channels, as the file's header has them."""
    probe = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path)], capture_output=True, text=True).stderr
    found = re.search(r"Audio: (\w+).*?, (\d+) Hz, (mono|stereo|\d+ channels)", probe)
    channels = {"mono": 1, "stereo": 2}.get(found.group(3)) or int(found.group(3).split()[0])
    return found.group(1), int(found.group(2)), channels


def measure(path: Path) -> dict:
    x = decode(path)
    peak = np.abs(x).max()
    spectrum = np.abs(np.fft.rfft(x)) ** 2
    hz = np.fft.rfftfreq(len(x), 1 / RATE)
    # The OGG's silence after its fade aside: where the sound really ends.
    end = np.flatnonzero(np.abs(x) > peak * 10 ** (-90 / 20))[-1] + 1
    starts = attacks(x)
    codec, rate, channels = stream_format(path)
    return {
        "duration_s": len(x) / RATE,
        "codec": codec, "rate": rate, "channels": channels,
        "lead_ms": 1000.0 * int(np.argmax(np.abs(x) >= peak * 10 ** (ONSET_DB / 20))) / RATE,
        "attack_ms": 1000.0 * int(np.argmax(np.abs(x) >= peak * 10 ** (ATTACK_DB / 20))) / RATE,
        "true_peak_db": true_peak(x),
        "loudness": loudness(x),
        "low_share": float(spectrum[hz < LOW_HZ].sum() / spectrum.sum()),
        "brightness_hz": float((hz * spectrum).sum() / spectrum.sum()),
        "crest_db": db(peak) - db(np.sqrt(np.mean(x[:int(0.05 * RATE)] ** 2))),
        "decay_ms": decay_ms(x),
        "events": len(starts),
        "end_attack": any(at > (end / RATE) - 0.02 for at in starts[1:]),
        "end_db": db(abs(x[end - 1])) - db(peak),
    }


def decay_ms(x: np.ndarray) -> float:
    """How long the sound takes from its peak to 30 dB under it (1 ms windows)."""
    env = envelope_db(x, 0.001, 0.001)
    top = int(env.argmax())
    under = np.flatnonzero(env[top:] < env[top] - 30.0)
    return float(under[0] if len(under) else len(env) - top)


def verdict(m: dict, role: dict) -> list[str]:
    fails = []
    if m["duration_s"] >= role["max_s"]:
        fails.append(f"duration {m['duration_s'] * 1000:.0f} ms, under {role['max_s'] * 1000:.0f} required")
    if (m["codec"] == "pcm_s16le") != (m["duration_s"] < WAV_UNDER_S) or m["codec"] not in ("pcm_s16le", "vorbis"):
        fails.append(f"{m['codec']} for {m['duration_s'] * 1000:.0f} ms (WAV under {WAV_UNDER_S * 1000:.0f} ms, else OGG)")
    if (m["rate"], m["channels"]) != (RATE, 1):
        fails.append(f"{m['rate']} Hz, {m['channels']} channels (48000 Hz mono required)")
    if m["lead_ms"] > 1.0:
        fails.append(f"lead silence {m['lead_ms']:.1f} ms")
    if m["attack_ms"] > role["max_attack_ms"]:
        fails.append(f"attack {m['attack_ms']:.0f} ms > {role['max_attack_ms']}")
    if m["true_peak_db"] > -1.0:
        fails.append(f"peak {m['true_peak_db']:.1f} dBFS")
    if abs(m["loudness"] - role["loudness"]) > 0.5:
        fails.append(f"loudness {m['loudness']:.1f}, role {role['loudness']}")
    if m["low_share"] > role["max_low_share"]:
        fails.append(f"{m['low_share'] * 100:.0f} % of the energy under {LOW_HZ:.0f} Hz")
    # Soft, as the user's ear chose: the sounds liked were dull and round, those turned down bright and sharp.
    if m["brightness_hz"] > role.get("max_bright_hz", np.inf):
        fails.append(f"bright: {m['brightness_hz']:.0f} Hz, at most {role['max_bright_hz']}")
    if m["crest_db"] > role.get("max_crest_db", np.inf):
        fails.append(f"sharp: its peak {m['crest_db']:.1f} dB over its first 50 ms, at most {role['max_crest_db']}")
    if m["decay_ms"] > role.get("max_decay_ms", np.inf):
        fails.append(f"lingers: {m['decay_ms']:.0f} ms to 30 dB under its peak, at most {role['max_decay_ms']}")
    if m["events"] > 1:
        fails.append(f"{m['events']} events")
    if m["end_attack"]:
        fails.append("an attack in its last 20 ms (click at the end)")
    if m["end_db"] > -50.0:
        fails.append(f"last sample {m['end_db']:.0f} dB under the peak")
    return fails


def draw(path: Path) -> None:
    common = [FFMPEG, "-v", "error", "-y", "-i", str(path)]
    subprocess.run([*common, "-lavfi", "showspectrumpic=s=640x240:legend=1:fscale=log:scale=log:stop=20000",
                    str(QA / f"{path.stem}.spectrogram.png")], check=True)
    subprocess.run([*common, "-lavfi", "showwavespic=s=640x160:split_channels=0:colors=0x3c8dbc",
                    str(QA / f"{path.stem}.waveform.png")], check=True)


def sheets(config: dict) -> None:
    """One picture per role: each sound's name, spectrogram and waveform, two to a row."""
    from PIL import Image, ImageDraw
    for role in config["roles"]:
        tiles = []
        for name in (n for n, sound, _ in entries(config) if sound["role"] == role):
            spectrogram = Image.open(QA / f"{name}.spectrogram.png").convert("RGB")
            waveform = Image.open(QA / f"{name}.waveform.png").convert("RGB")
            tile = Image.new("RGB", (spectrogram.width, 28 + spectrogram.height + waveform.height), "white")
            ImageDraw.Draw(tile).text((8, 6), name, fill="black")
            tile.paste(spectrogram, (0, 28))
            tile.paste(waveform, ((spectrogram.width - waveform.width) // 2, 28 + spectrogram.height))
            tiles.append(tile)
        if not tiles:
            continue
        width, height = tiles[0].size
        sheet = Image.new("RGB", (2 * width, (len(tiles) + 1) // 2 * height), "white")
        for i, tile in enumerate(tiles):
            sheet.paste(tile, (i % 2 * width, i // 2 * height))
        sheet.save(QA / f"sheet-{role}.png")


def recipe_sha256(config: dict, name: str) -> str:
    """What makes sound [name]: its recipe and its role's levels."""
    sound = config["sounds"][name]
    return hashlib.sha256(json.dumps([sound, config["roles"][sound["role"]]], sort_keys=True).encode()).hexdigest()


def qa() -> None:
    config = load_json("sounds.json")
    roles = config["roles"]
    # A sound the user validated by ear keeps its recipe: changing it needs their word, then a new sha256.
    for name, validated in config.get("validated", {}).items():
        if recipe_sha256(config, name) != validated["recipe_sha256"]:
            sys.exit(f"sounds.json: {name} was validated by the user on {validated['date']}; its recipe changed")
    if not roles["scroll"]["loudness"] <= roles["nav"]["loudness"] < roles["action"]["loudness"]:
        sys.exit("sounds.json: the games' scroll must be the quietest, navigation quieter than validation")
    QA.mkdir(parents=True, exist_ok=True)
    (QA / ".gdignore").touch()
    rows, results = [], {}
    for name, sound, folder in entries(config):
        role = roles[sound["role"]]
        path = sound_path(name, folder)
        m = measure(path)
        fails = verdict(m, role)
        draw(path)
        state = "FAIL" if fails else "PASS"
        results[name] = {**m, "role": sound["role"], "verdict": state, "fails": fails}
        rows.append(f"| {name} | {sound['role']} | {path.suffix[1:]} | {m['duration_s'] * 1000:.0f} | {m['lead_ms']:.2f} "
                    f"| {m['attack_ms']:.1f} | {m['true_peak_db']:.1f} | {m['loudness']:.1f} | {m['low_share'] * 100:.0f} % "
                    f"| {m['events']} | {state}{': ' + '; '.join(fails) if fails else ''} |")
    role_rows = "\n".join(f"| {r} | {v['loudness']} | {v['max_s'] * 1000:.0f} | {v['max_attack_ms']} "
                          f"| {v['max_low_share'] * 100:.0f} % |" for r, v in roles.items())
    sheets(config)
    (QA / "report.json").write_text(json.dumps(results, indent=1))
    (QA / "REPORT.md").write_text(
        "# Sound QA\n\nMade by `scripts/audio/sfx.py qa`. Every sound: 48 kHz mono, WAV (16 bits) under "
        f"{WAV_UNDER_S * 1000:.0f} ms, else OGG; true peak (4× oversampled) at most -1 dBFS; no lead silence (it "
        f"reaches {ONSET_DB:.0f} dB under its peak within 1 ms); one event (an event starts where at least "
        f"{ONSET_SHARE * 100:.0f} % of the bands from 300 Hz to 16 kHz rise {ONSET_RISE_DB:.0f} dB within 2 ms, down to "
        f"{AUDIBLE_DB:.0f} dB under the loudest moment; attacks closer than {EVENT_GAP_S * 1000:.0f} ms are one); "
        f"no attack in the last 20 ms, and a last sample 50 dB under the peak "
        f"(a {FADE_OUT_S * 1000:.0f} ms fade). Loudness: "
        f"K-weighted energy (ITU-R BS.1770) over the loudest {LOUDNESS_WINDOW_S * 1000:.0f} ms, ungated, in LKFS, "
        f"within 0.5 of the role's. Attack: time to come within {-ATTACK_DB:.0f} dB of the peak. Soft (where the role "
        "sets it): brightness, the spectral centroid, and sharpness, the peak over the first 50 ms' RMS, at most "
        "the role's; dry (where the role sets it): from its peak to 30 dB under it within the role's time.\n\n"
        "| Role | Loudness | Shorter than (ms) | Longest attack (ms) | Most energy under 300 Hz |\n"
        f"|---|---|---|---|---|\n{role_rows}\n\n| Sound | Role | File | ms | Lead ms | Attack ms | True peak dBFS "
        "| Loudness | < 300 Hz | Events | Verdict |\n"
        "|---|---|---|---|---|---|---|---|---|---|---|\n" + "\n".join(rows) + "\n")
    print("\n".join(rows))
    failed = sum(r["verdict"] == "FAIL" for r in results.values())
    print(f"{failed} failed, {len(rows) - failed} passed, of {len(rows)}")
    sys.exit(1 if failed else 0)



# map

MAP = ROOT / "build" / "sound-map"
# How a verdict reads on the map, in the user's words.
VERDICTS = {"validated": "validé", "promising": "bonne piste", "refused": "refusé", "untreated": "à écouter"}
MAP_STYLE = """
:root { --bg: #f3f4f7; --panel: #ffffff; --fg: #1d2230; --muted: #636b7d; --line: #dfe2ea; --accent: #3b5bdb;
  --validated: #2f9e44; --promising: #e8890c; --refused: #e03131; --untreated: #9aa1b1;
  --display: "Sora", "Segoe UI", sans-serif; --body: "IBM Plex Sans", "Segoe UI", sans-serif; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg: #12151c; --panel: #1b1f29; --fg: #e8eaf0;
  --muted: #9aa1b1; --line: #2c3240; --accent: #7c95f5; --untreated: #6b7282; color-scheme: dark } }
:root[data-theme="dark"] { --bg: #12151c; --panel: #1b1f29; --fg: #e8eaf0; --muted: #9aa1b1; --line: #2c3240;
  --accent: #7c95f5; --untreated: #6b7282; color-scheme: dark }
body { background: var(--bg); color: var(--fg); font: 15px/1.5 var(--body);
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
main { max-width: 980px; margin: 0 auto; padding-block: 28px 64px; display: grid; gap: 28px; }
h1, h2, h3 { font-family: var(--display); text-wrap: balance; margin: 0; }
h1 { font-size: 1.9rem; } h2 { font-size: 1.3rem; } h3 { font-size: 1.02rem; }
p { margin: 0; max-width: 68ch; color: var(--muted); }
nav { display: flex; gap: 8px; flex-wrap: wrap; }
nav a { color: var(--fg); text-decoration: none; border: 1px solid var(--line); border-radius: 999px; padding: 6px 14px;
  background: var(--panel); }
nav a[aria-current="true"] { border-color: var(--accent); color: var(--accent); }
.legend { display: flex; gap: 14px; flex-wrap: wrap; font-size: .85rem; color: var(--muted); }
.dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; vertical-align: 0; }
.validated { --tone: var(--validated); } .promising { --tone: var(--promising); } .refused { --tone: var(--refused); }
.untreated { --tone: var(--untreated); }
.dot, .chip .dot { background: var(--tone); }
.screens, .sounds { display: grid; gap: 16px; }
.sounds { grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); }
section.card { background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 16px 18px;
  display: grid; gap: 10px; min-width: 0; }
.rows { display: grid; gap: 2px; }
.row { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 6px 0;
  border-top: 1px solid var(--line); }
.row:first-child { border-top: 0; }
.chip { display: inline-flex; align-items: center; gap: 6px; border: 1px solid var(--line); border-radius: 999px;
  padding: 4px 12px 4px 10px; background: var(--bg); color: var(--fg); font: inherit; font-size: .9rem; cursor: pointer;
  white-space: nowrap; }
.chip:hover { border-color: var(--tone); }
.chip:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.chip.playing { border-color: var(--tone); box-shadow: 0 0 0 2px color-mix(in srgb, var(--tone) 30%, transparent); }
.chip .play { font-size: .7rem; color: var(--muted); }
.mute { font-size: .85rem; color: var(--muted); font-style: italic; }
.sound-head { display: flex; justify-content: space-between; align-items: center; gap: 10px; flex-wrap: wrap; }
.verdict { font-size: .8rem; color: var(--tone); font-weight: 600; letter-spacing: .02em; }
ul { margin: 0; padding-left: 18px; color: var(--muted); font-size: .9rem; display: grid; gap: 2px; }
ul b { color: var(--fg); font-weight: 500; }
.note { font-size: .85rem; }
@media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
"""
MAP_SCRIPT = """
const players = {};
let last = null;
document.addEventListener('click', (e) => {
  const chip = e.target.closest('.chip');
  if (!chip) return;
  const file = chip.dataset.file;
  players[file] ??= new Audio('sounds/' + file);
  if (last) last.classList.remove('playing');
  last = chip;
  chip.classList.add('playing');
  const audio = players[file];
  audio.currentTime = 0;
  audio.onended = () => chip.classList.remove('playing');
  audio.play();
});
function show() {
  const view = location.hash === '#sons' ? 'sons' : 'ecrans';
  for (const part of document.querySelectorAll('[data-view]')) part.hidden = part.dataset.view !== view;
  for (const link of document.querySelectorAll('nav a')) link.setAttribute('aria-current', link.hash === '#' + view);
}
addEventListener('hashchange', show);
show();
"""


def map_page(config: dict) -> str:
    """Every screen with its gestures and the sound each plays, then every sound with where it plays: the one place
    that says which sound goes with which gesture, made from sounds.json so it cannot drift from the app."""
    found = board(config)
    labels, cue_sounds, verdicts = found["labels"], found["cues"], found["sounds"]
    e = html.escape

    def chip(sound: str) -> str:
        status = verdicts[sound]["status"]
        return (f'<button class="chip {status}" type="button" data-file="{e(sound_path(sound).name)}" '
                f'title="{e(VERDICTS[status])}"><span class="dot"></span>{e(labels[sound])}<span class="play">▶</span></button>')

    screens = "".join(
        f'<section class="card"><h3>{e(name)}</h3><div class="rows">' + "".join(
            f'<div class="row"><span>{e(what)}</span>'
            + (chip(cue_sounds[cue]) if cue_sounds[cue] else '<span class="mute">muet</span>') + "</div>"
            for what, cue in gestures) + "</div></section>"
        for name, gestures in found["screens"])
    sounds = ""
    for family, members in found["categories"]:
        for sound in members:
            where = [f"<li><b>{e(screen)}</b> : {e(what)}</li>" for screen, gestures in found["screens"]
                     for what, cue in gestures if cue_sounds[cue] == sound]
            status = verdicts[sound]["status"]
            sounds += (f'<section class="card"><div class="sound-head">{chip(sound)}'
                       f'<span class="verdict {status}">{e(VERDICTS[status])}</span></div>'
                       f'<p class="note">{e(family)}{" · " + e(verdicts[sound]["note"]) if verdicts[sound]["note"] else ""}</p>'
                       f'<ul>{"".join(where)}</ul></section>')
    tries = "".join(
        f'<div class="row"><span>{e(labels[cue_sounds[name.rsplit("_", 1)[0]]])}, autre piste ({e(name[-1])})</span>'
        f'<button class="chip untreated" type="button" data-file="../candidates/{e(sound_path(name, CANDIDATES).name)}">'
        f'<span class="dot"></span>écouter<span class="play">▶</span></button></div>' for name in config.get("candidates", {}))
    if tries:
        screens = (f'<section class="card"><h3>À comparer</h3><p class="note">D\'autres pistes pour un son, '
                   f'à écouter à côté de celui de l\'app.</p><div class="rows">{tries}</div></section>') + screens
    legend = "".join(f'<span class="{status}"><span class="dot"></span>{e(word)}</span>' for status, word in VERDICTS.items())
    return (f'<title>Carte des sons</title>\n'
            '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600'
            '&family=Sora:wght@600&display=swap">\n'
            f"<style>{MAP_STYLE}</style>\n<main><header style=\"display:grid;gap:10px\"><h1>Carte des sons</h1>"
            "<p>Chaque écran de Cartouche, chaque geste et le son qu'il joue. Touchez un son pour l'écouter. "
            f"Un même son revient partout où le geste a le même sens.</p><div class=\"legend\">{legend}</div>"
            '<nav><a href="#ecrans">Par écran</a><a href="#sons">Par son</a></nav></header>'
            f'<div class="screens" data-view="ecrans">{screens}</div>'
            f'<div class="sounds" data-view="sons" hidden>{sounds}</div></main>\n<script>{MAP_SCRIPT}</script>\n')


def map_() -> None:
    config = load_json("sounds.json")
    (MAP / "sounds").mkdir(parents=True, exist_ok=True)
    (MAP / "candidates").mkdir(exist_ok=True)
    for sound, folder in [(s, SFX) for s in config["sounds"]] + [(s, CANDIDATES) for s in config.get("candidates", {})]:
        source = sound_path(sound, folder)
        (MAP / ("sounds" if folder == SFX else "candidates") / source.name).write_bytes(source.read_bytes())
    (MAP / "index.html").write_text(map_page(config))
    print(MAP / "index.html")

if __name__ == "__main__":
    commands = {"render": render, "qa": qa, "map": map_}
    if len(sys.argv) == 2 and sys.argv[1] in commands:
        commands[sys.argv[1]]()
    else:
        sys.exit(__doc__)
